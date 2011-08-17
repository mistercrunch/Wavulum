/*
 * Library for interfacing an AVR with a TLC5940 16-channel PWM LED driver.
 *
 * Copyright 2007 Marius Kintel <kintel@sim.no>
 * http://www.metalab.at
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 */

#include <avr/interrupt.h>
#include <stdlib.h>
#include "TLC5940.h"

// Arduino pins (corresponds to the AVR pins below):
//   SCLK_PIN  =  8
//   XLAT_PIN  =  9
//   BLANK_PIN = 10
//   GSCLK_PIN = 11
//   VPRG_PIN  = 12
//   SIN_PIN   = 13

// AVR pins:
#define TLCPORT PORTB
#define SCLK_PIN PB0
#define XLAT_PIN PB1
#define BLANK_PIN PB2
#define GSCLK_PIN PB3
#define VPRG_PIN PB4
#define SIN_PIN PB5

static volatile bool tlc5940_needpulse = false;
static volatile bool tlc5940_transferdone = false;

// If this is commented out, slow PWM mode is enabled for testing
#define FAST

/*!
  Constructor.

  \e numdrivers defines the number of TLC5940 chips connected in series. 
  Each chip controls 16 leds.

  \e resolution defines the number of bits of LED grayscale intensities, thus defining
  the grayscale resolution. It defaults to the highest possible value, 12.
 */
TLC5940::TLC5940(uint8_t numdrivers, uint8_t resolutionbits)
{
  this->numdrivers = numdrivers;
  this->shiftbits = 12 - resolutionbits;

  this->frame = (uint8_t *)malloc(numdrivers*24); // 24 bytes (192 bits) per driver chip
  this->clear();
}

TLC5940::~TLC5940()
{
  free(this->frame);
}

static void shift6(uint8_t v)
{
  for (uint8_t i=0x20;i;i>>=1) {
    if (v&i) TLCPORT |= _BV(SIN_PIN);
    else TLCPORT &= ~_BV(SIN_PIN);
    TLCPORT |= _BV(SCLK_PIN);
    TLCPORT &= ~_BV(SCLK_PIN);
  }
}

static void shift8(uint8_t v)
{
  for (uint8_t i=0x80;i;i>>=1) {
    if (v&i) TLCPORT |= _BV(SIN_PIN);
    else TLCPORT &= ~_BV(SIN_PIN);
    TLCPORT |= _BV(SCLK_PIN);
    TLCPORT &= ~_BV(SCLK_PIN);
  }
}

/*!
  Temporary method for setting global dot correction.
  It is initialized by default to 63.

  NB! This function might hang if the interrupts are not running.
 */
void
TLC5940::setGlobalDC(uint8_t dcval)
{
  while (tlc5940_transferdone) {}
  PORTB |= _BV(VPRG_PIN);
  for (uint8_t i=0;i<this->numdrivers*16;i++) shift6(dcval);
  PORTB |= _BV(XLAT_PIN);
  PORTB &= ~_BV(XLAT_PIN);
  PORTB &= ~_BV(VPRG_PIN);

  tlc5940_needpulse = true;
}

/*!
  Initialized drivers and starts interrupts.
 */
void
TLC5940::init()
{
  cli();

  // Set pins to output
  DDRB |= 
    _BV(BLANK_PIN) | _BV(XLAT_PIN) | _BV(SCLK_PIN) | 
    _BV(SIN_PIN) | _BV(GSCLK_PIN) | _BV(VPRG_PIN);

  TLCPORT &= ~_BV(BLANK_PIN);   // blank everything until ready
  TLCPORT &= ~_BV(XLAT_PIN);
  TLCPORT &= ~_BV(SCLK_PIN);
  TLCPORT &= ~_BV(GSCLK_PIN);

  setGlobalDC(63); // Max intensity.

  // PWM timer
  TCCR2A = (_BV(WGM21) |   // CTC 
            _BV(COM2A0));  // toggle OC2A on match -> GSCLK
  TCCR2B = _BV(CS20);      // No prescaler
#ifdef FAST
  OCR2A = 1;               // toggle every timer clock cycle -> 4 MHz
#else
  OCR2A = 32;               // toggle every 16 timer clock cycle -> 4/16 MHz
#endif
  TCNT2 = 0;

  // Latch timer
  TCCR1A = (_BV(WGM10));   // Fast PWM 8-bit
#ifdef FAST
  TCCR1B = (_BV(CS11) |    // /64 prescaler     =>
            _BV(CS10) |
#else
  TCCR1B = (_BV(CS12) |    // /1024 prescaler     =>
            _BV(CS10) |
#endif
            _BV(WGM12));   // Fast PWM 8-bit  =>  1/4096th of OC2A
  TIMSK1 = _BV(TOIE1);     // Enable overflow interrupt
  TCNT1 = 0;

  sei();

  display();
}

void
TLC5940::clear()
{
  for (uint8_t i=0;i<this->numdrivers*24;i++) {
    frame[i] = 0;
  }
}

/*!
  Sets the intensity of led nr \e lednr.
  The intensity value must fit in the number of \e resolutionbits passed
  to init().
 */
void
TLC5940::setLED(uint8_t lednr, uint16_t intensity)
{
  uint16_t bitnr = lednr * 12; // 12 bits per led
  uint8_t bytenr = bitnr >> 3;
  bool startnibble = (bitnr & 7)?true:false;

  intensity <<= this->shiftbits;

  if (!startnibble) {
    this->frame[bytenr] = intensity >> 4;
    this->frame[bytenr+1] = 
      (this->frame[bytenr+1] & 0x0f) | ((intensity & 0x0f) << 4);
  }
  else {
    this->frame[bytenr] = 
      (this->frame[bytenr] & 0xf0) | (intensity >> 8);
    this->frame[bytenr+1] = intensity & 0xff;
  }
}

uint16_t
TLC5940::getLED(uint8_t lednr)
{
  uint16_t bitnr = lednr * 12; // 12 bits per led
  uint8_t bytenr = bitnr >> 3;
  bool startnibble = (bitnr & 7)?true:false;

  if (!startnibble) {
    return this->frame[bytenr] << 4 | this->frame[bytenr+1] >> 4;
    
  }
  else {
      return ((uint16_t)this->frame[bytenr] & 0xf0) << 4 | this->frame[bytenr+1];
  }
}


/*!
  Displays the current frame.
  
  NB! This function will hang if the interrupts are not running.
*/
void
TLC5940::display()
{
  while (tlc5940_transferdone) {}
  
  TLCPORT &= ~_BV(VPRG_PIN);
  for (uint8_t i=0;i<numdrivers*24;i++) {
    shift8(frame[i]);
  }
  tlc5940_transferdone = true;
}


/*!
  Overflow interrupt. Handles BLANK and latches on demand.
*/
ISR(TIMER1_OVF_vect)
{
  TLCPORT |= _BV(BLANK_PIN);

  // Stop timers
#ifdef FAST
  TCCR1B &= ~_BV(CS11);
#else
  TCCR1B &= ~_BV(CS12);
#endif
  TCCR2B &= ~_BV(CS20);

  // Latch only if new data is available
  if (tlc5940_transferdone) {
    TLCPORT |= _BV(XLAT_PIN); // latch
    TLCPORT &= ~_BV(XLAT_PIN);
    tlc5940_transferdone = false;
    
    // Extra SCLK pulse according to Datasheet p.18
    if (tlc5940_needpulse) {
      TLCPORT |= _BV(SCLK_PIN);
      TLCPORT &= ~_BV(SCLK_PIN);
      tlc5940_needpulse = false;
    } 
  }

  TLCPORT &= ~_BV(BLANK_PIN);

  // Restart timers
  TCNT2 = 0;
  TCNT1 = 0;
#ifdef FAST
  TCCR1B |= _BV(CS11);
#else
  TCCR1B |= _BV(CS12);
#endif
  TCCR2B |= _BV(CS20);
}

