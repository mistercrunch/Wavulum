#ifndef TLC5940_H_
#define TLC5940_H_

#include <stdint.h>


class TLC5940
{
public:
  TLC5940(uint8_t numdrivers, uint8_t resolutionbits = 12);
  ~TLC5940();

  void init();
  void clear();
  void setLED(uint8_t lednr, uint16_t intensity);
  uint16_t getLED(uint8_t lednr);
  void display();

  void setGlobalDC(uint8_t dcval);

private:
  uint8_t shiftbits;
  uint8_t numdrivers;
  uint8_t *frame;
};

#endif
