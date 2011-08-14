


/*
--------------------------------------------------------------------------------------------------------------------
Project: LedHat
--------------------------------------------------------------------------------------------------------------------
What it does: 
Flashes RGB leds in a controllable randomness fashion. 

Input (user controlled parameters):
* Button 1: Changes the cycle mode (color picking, flashing, fade-in/cut, fade-in/fade-out, fade into next color, sweep the palette range)
* Poto 1: Cycle speed
* Poto 2: Color picker (Fades from R, to G, to B, back to R)
* Poto 3: Brightness (fades from dark, to color picked, to white)
* Poto 4: Color randomness (defines the size of a square random domain for color variation)

Output:
* RGB LEDs

Hardware Electronic
* Arduino Board
* Ti 5940 16-port PWM LED driver (caisy chainable: Allows 5 RGB LEDs per chip) (6 free as samples from Texas Instruments, otherwise they'd be 4.28 bucks each at www.digikey.com)
* Common anode RGB LEDs (common cathode won't work with the TLC5940s) (50 for 20$)

Hard Hardware

* Ping pong balls 
* Helmet (yet to buy)
* Mirors (disco ball effect on helmet, huge bag of pre-cut square mirrors for 20$)
* Metal saw to cut each RGB led's top, for better diffusion in the ping pong ball

Itemized costs:
* Barebone Freeduino kit                  = 10
* Wiring (Fry's)                          = 10 
* LEDs (ultrabright common anode, ebay)   = 10 (50 for 20$ on eBay)
* Ping Pong balls (eBay)                  =  5 (72 for 11$ on eBay)
* Helmet (chromed, eBay)                  = 30
* Other (glue, casing, pots)              = 10 
* 4* TLC5940NT LED driver chips           =  0 (free as Texas Instrument samples)

Thanks to:
* David Cuartielles's & Marcus Hannerstig's for low level logic logic on how to control the TLC5940
* The Internets and the awesome DC and Arduino community

-------------------------------
Memory EEPROM=512
-------------------------------

4 pots * 8 bits        = 32bits
Cyclemode 4 bits       =  4bits
2 colors * 2 times * 8 = 32bits 
-------------------------------
Total = 68 bits, or 7.5 memory spots
-------------------------------

To do:
* Test intensity pot
* Put 2 buttons on helmet

--------------------------------------------------------------------------------------------------------------------
Estimated power consumption
LED = 17 * 20ma = 340
*/
#include </home/mistercrunch/Programs/arduino/libraries/TLC5940/TLC5940.h>
#include </home/mistercrunch/Programs/arduino/libraries/TLC5940/TLC5940.cpp>

// https://whatever.metalab.at/user/wizard23/tlc5940/arduino/TLC5940/

#include <EEPROM.h>
TLC5940 leds(9, 12);
// Arduino pins (corresponds to the AVR pins below):
//   SCLK_PIN  =  8
//   XLAT_PIN  =  9
//   BLANK_PIN = 10
//   GSCLK_PIN = 11
//   VPRG_PIN  = 12
//   SIN_PIN   = 13

//Program Constants
#define btnMode 2//Arduino pin 0 is used for "Button 1" (changes cycle mode, push = next mode)
#define btnMem 3
#define MSINTRVL 15      //Can be used to delay the execution of the code, without interfering with the low level code necessities
#define NBLEDS 16        //Number of RGB LEDs connected (Each RGB LED uses 3 channels)
#define PWMRANGE 4096   //PWM range on the TLC5940
#define EventCheckDelay 30 //Interval at which we look for input changes (pots and buttons)

//Program Variables

//Operational variables 
int curR[NBLEDS];
int curG[NBLEDS];
int curB[NBLEDS];
int toR[NBLEDS];
int toG[NBLEDS];
int toB[NBLEDS];
int origR[NBLEDS];
int origG[NBLEDS];
int origB[NBLEDS];
int cycleNbFrame[NBLEDS];
int currentFrame[NBLEDS];
//Other operational variables
boolean btnModeLastStatus = 1;       //Used for tracking button push (was pressed, now unpressed)
boolean btnMemLastStatus = 1;
boolean iStatus = 0;                 //Also used for tracking button push (was pressed, now unpressed)
unsigned long prevMillis;            //used for a timing delay
unsigned long curMillis=0;           //used to avoid calling the function millis() many times
unsigned long LastEventCheck = 0;    //Stores the last time we read inputs

//------------------------------------------------------------------------------------------------------------
//Pattern variables
  byte CycleMode = 0;               //Cycle mode (1-flashing, 2-fade-in/cut, 3-fade-in/fade-out, 4-fade into next color)
  int PotCycleSpeed = 10;           //Initial value for the Poto1 (determines cycle speed)
  int PotColorRandomness = 1023;    //Initial value for the Poto3 (color randomness)
  int iNbColor=1;
  int iRefColor[3];
  int iBrightness[3];
//------------------------------------------------------------------------------------------------------------
//High level vars
int iAutoMode =1;//defines the high level mode (auto memory, auto random, manual)
int iCurrentPattern =-1; //Applies to auto mode memory only
//These help keeping track of the patterns cycles in auto mode
long unsigned iSequenceStartTime=0;
unsigned int iSequenceDuration=0;
//------------------------------------------------------------------------------------------------------------

//

//---------------------------------------------------------------------------------------------------------------------------------------
void setup() {

  pinMode(btnMode, INPUT); 
  pinMode(btnMem, INPUT); 

  //randomSeed(analogRead(1));

  leds.init();
  leds.clear(); // Clear framebuffer
  leds.display(); // Display framebuffer

  //beginSerial(9600); //in case of debugging
  //Serial.println("Ready...");
  //ClearEeprom();
  CheckButtons();
  StartNextPattern();
}

void loop () {
  curMillis = millis();
  
  //Checking events and user input 
  
  if(curMillis > (LastEventCheck + EventCheckDelay))
  {
    CheckButtons();
    if (iAutoMode==0) ReadPots();
    else ManageAutoMode();
    LastEventCheck = curMillis;
    
  } 
  
  //Calculating next frame 
  if (curMillis > (prevMillis+MSINTRVL))
  {
    for(int i=0; i<NBLEDS; i++)
    //For each RGB LED
    {
      calcFrame(i);
    }
    prevMillis=curMillis;
    DisplayLEDs();    
    
  }
  
}
//------------------------------------------------------------------------------------------------------------------------------------------------
//--EEPROM shnuff (memory management)
//------------------------------------------------------------------------------------------------------------------------------------------------

void WriteIntToEEPROM(int address, int value)
{
  EEPROM.write(address+1, value);
  value = value >> 8;
  EEPROM.write(address, value);
}

int ReadIntFromEEPROM(int address)
{
  int value = EEPROM.read(address);
  value = value << 8;
  value = value + EEPROM.read(address+1);  
  return value;
}


void StoreNewPattern()
{
   int iNbPatterns = ReadIntFromEEPROM(0);
   WriteIntToEEPROM(0, iNbPatterns+1);
   if(iNbPatterns<=20)
       WritePattern(iNbPatterns);
   else
   {
     for(int i=0; i<10; i++) 
     {
       FadeToColor(100, PWMRANGE-1,0,0); //MEMORY IS FULL, flash red 10 times
     }
   }
}

void WritePattern(int iPatternNumber)
{
   int iStartAddress = (iPatternNumber * 2 * 10) + 2;
   
   WriteIntToEEPROM(iStartAddress,        CycleMode);
   WriteIntToEEPROM(iStartAddress + 2,   PotCycleSpeed);
   WriteIntToEEPROM(iStartAddress + 4,   PotColorRandomness);
   WriteIntToEEPROM(iStartAddress + 6,   iNbColor);
   WriteIntToEEPROM(iStartAddress + 8,   iRefColor[0]);
   WriteIntToEEPROM(iStartAddress + 10,   iBrightness[0]);  
   WriteIntToEEPROM(iStartAddress + 12,   iRefColor[1]);
   WriteIntToEEPROM(iStartAddress + 14,   iBrightness[1]);
   WriteIntToEEPROM(iStartAddress + 16,   iRefColor[2]);
   WriteIntToEEPROM(iStartAddress + 18,   iBrightness[2]);

   PrintPattern(iPatternNumber);
}

void ReadPattern(int iPatternNumber)
{
   int iStartAddress = (iPatternNumber * 2 * 10) + 2;
   
   CycleMode             = ReadIntFromEEPROM(iStartAddress);
   PotCycleSpeed         = ReadIntFromEEPROM(iStartAddress + 2);
   PotColorRandomness    = ReadIntFromEEPROM(iStartAddress + 4);
   
   iNbColor              = ReadIntFromEEPROM(iStartAddress + 6);
   iRefColor[0]          = ReadIntFromEEPROM(iStartAddress + 8);
   iBrightness[0]        = ReadIntFromEEPROM(iStartAddress + 10);
   iRefColor[1]          = ReadIntFromEEPROM(iStartAddress + 12);
   iBrightness[1]        = ReadIntFromEEPROM(iStartAddress + 14);
   iRefColor[2]          = ReadIntFromEEPROM(iStartAddress + 16);
   iBrightness[2]        = ReadIntFromEEPROM(iStartAddress + 18);
   
   PrintPattern(iPatternNumber);
}
void PrintPattern(int iPatternNumber)
{  
   Serial.print("Pattern  ");
   Serial.print(iPatternNumber+1);
   Serial.print("/");
   Serial.print(ReadIntFromEEPROM(0));
   Serial.println("");
   
   Serial.print("CycleMode: ");
   int i=(int)CycleMode;
   Serial.print(i);
   Serial.println("");
   
   Serial.print("PotCycleSpeed: ");
   Serial.print(PotCycleSpeed);
   Serial.println("");
   
   Serial.print("PotColorRandomness: ");
   Serial.print(PotColorRandomness);
   Serial.println("");
   
   Serial.print("iNbColor: ");
   Serial.print(iNbColor);
   Serial.println("");
   
   Serial.print("iRefColor[0]: ");
   Serial.print(iRefColor[0]);
   Serial.println("");
   
   Serial.print("iBrightness: ");
   Serial.print(iBrightness[0]);
   Serial.println("");
   
   Serial.print("iRefColor: ");
   Serial.print(iRefColor[1]);
   Serial.println("");
   
   Serial.print("iBrightness: ");
   Serial.print(iBrightness[1]);
   Serial.println("");
   
   Serial.print("iRefColor: ");
   Serial.print(iRefColor[2]);
   Serial.println("");
   
   Serial.print("iBrightness: ");
   Serial.print(iBrightness[2]);
   Serial.println("");
   
   Serial.println("");
}
void DeletePattern(int iPatternNumber)
{
   Serial.println("Deleting pattern!");
   int iNbPatterns = ReadIntFromEEPROM(0);
   
   for(int i=iPatternNumber+1;i<iNbPatterns; i++)
   {
     ReadPattern(i);
     WritePattern(i-1);
   }
   WriteIntToEEPROM(0, iNbPatterns - 1);
}

void ClearEeprom()
{
  //Doesn't really clear it all, it just resets the pattern number to 0
  for(int i=0; i<16; i++)
  {
     EEPROM.write(i, 0);
  }
}
//------------------------------------------------------------------------------------------------------------------------------------------------
void LoadNextPattern()
{
        int iNbPatterns = ReadIntFromEEPROM(0);
        iCurrentPattern++;
        FinishAllCycles();
        if (iCurrentPattern > iNbPatterns-1) iCurrentPattern = 0; // we've reached the last pattern, restarting with first
        ReadPattern(iCurrentPattern); //Loading pattern from EEPROM
}

void LoadPreviousPattern()
{
        int iNbPatterns = ReadIntFromEEPROM(0);
        iCurrentPattern--;
        FinishAllCycles();
        if (iCurrentPattern < 0) iCurrentPattern = iNbPatterns-1; // we've reached the last pattern, restarting with first
        ReadPattern(iCurrentPattern); //Loading pattern from EEPROM
}


void ManageAutoMode()
{
  int iTmpPotCycleSpeed = analogRead(2);
  boolean bSkipLoop = false;
  
  if (iTmpPotCycleSpeed >900) 
    bSkipLoop = true;
  else 
    iSequenceDuration = 2000 + (60 * iTmpPotCycleSpeed);
    
  if (millis() > iSequenceStartTime + iSequenceDuration && !bSkipLoop) 
      StartNextPattern();
}

void StartNextPattern()
{
    iNbColor=1;
    iSequenceStartTime = millis();
  
    if (iAutoMode==1)
    {
      
      int iNbPatterns = ReadIntFromEEPROM(0);
      
      if (iNbPatterns ==0)
        iAutoMode=2;//No patterns in memory, switching to random mode
      else
      
        LoadNextPattern();
    }
  
    if(iAutoMode==2)
      AssignRandomPotValues();
}     
void AssignRandomPotValues()
{
      //Assiging ramdom values for all pots
      iRefColor[0] = random(1024) * 3 * 4;  //any color as the ref
      iBrightness[0] = 512;//sticking with pure colors only
      PotColorRandomness  = random(800);//limiting color range to 1/2 at most  
      PotCycleSpeed = (random(1024) / 10) + 1;   
      CycleMode = random(5) ; 
}

byte CheckButton(int btnId)
{
  //This function looks to see if a button has been pushed and shows a little animation while the button is down
  if(digitalRead(btnId) ==0)
    return 0;
  else
  {
      //Button is down
      unsigned long lBtnPushed = millis();
      while(digitalRead(btnId) ==1 && ((millis() - lBtnPushed) < 3000))
      {
          ClearCurRGB();
          //-----------------------
          //Different animation for the two buttons
           if (btnId==btnMode)
          {
            int iRandLED = random(17);
            curR[iRandLED] = PWMRANGE -1;
            curG[iRandLED] = PWMRANGE -1;
            curB[iRandLED] = PWMRANGE -1;
            if (digitalRead(btnMem)==1) return 3;//both buttons
          }
          else
          {
            int iRandLED = random(17);
            curR[iRandLED] = PWMRANGE-1;
            iRandLED = random(17);
            curG[iRandLED] = PWMRANGE-1;
            iRandLED = random(17);
            curB[iRandLED] = PWMRANGE-1;
            if (digitalRead(btnMode)==1) return 3;//both buttons
          }
          //-----------------------
          DisplayLEDs();    
          delay(30);
      }
      if (millis() - lBtnPushed < 3000)
        return 1; //1 is for short push
      else
        return 2; //2 is for long push    
  }
}

void FadeToColor(int iDelay, int R,int G,int B)
{
        //No event check, will stop current execution to do this fade
        ClearCurRGB();
        for(int i=0; i<iDelay; i++)
        {
          for(int iLED =0; iLED<NBLEDS; iLED++)
          {
            curR[iLED] = ((float)i / (float)iDelay) * R;
            curG[iLED] = ((float)i / (float)iDelay) * G;
            curB[iLED] = ((float)i / (float)iDelay) * B;
          }
          DisplayLEDs();
          delay(1);
        }
}

void CheckButtons()
{
  int btnModeStatus = CheckButton(btnMode);
  int btnMemStatus = CheckButton(btnMem);
  
  if (btnMemStatus == 3 || btnModeStatus ==3)
  {
    //If two buttons are pushed at the same time, we're switching auto mode (from pattern, to random patterns, to manual)

    FinishAllCycles();    
    iAutoMode++;
    if (iAutoMode >2) iAutoMode=0;
    
    if (iAutoMode == 0)          
    { 
      //Manual mode
      iNbColor=1; //resets colors to only one
      CycleMode=0;  //resets flashing mode to default
      FadeToColor(1000, 0,0,PWMRANGE-1); //Pulsing blue to let the user know he is in MANUAL  mode
    } 
    else if (iAutoMode == 1)     
    {
       //Memory cycle mode
       LoadNextPattern();
       FadeToColor(1000, PWMRANGE-1,0,0);
    }
    else if (iAutoMode == 2)     
    { 
      StartNextPattern();
      FadeToColor(1000, 0,PWMRANGE-1,0);
    }
  }
  
  if (iAutoMode ==1)
  {
    //We're in auto mode: the auto mode that cycles through patterns stored in memory
    if (btnMemStatus==1) LoadNextPattern();
    if (btnModeStatus==1) LoadPreviousPattern();
    if (btnMemStatus==2) 
    {
      //The button has been held, delete? Will flash red 5 times over 1 sec, if the button is still down after that: DELETE pattern
      int i=0;
      while(i<5 && digitalRead(btnMem)==1)
      {
        FadeToColor(200, PWMRANGE-1,0,0); //Flash 5 times
        i++;
      }
      if(i==5) 
      {
        //Serial.println("Deleting pattern");
        DeletePattern(iCurrentPattern);
        FadeToColor(200, 0,PWMRANGE-1,0); //Pulse white to confirm deletion
        
      }    
    }
    if (btnModeStatus==2) 
    {
      //The mode button has been held, reset the Eeprom? Will flash red 5 times over 5 sec, if the button is still down after that: DELETE pattern
      int i=0;
      while(i<5 && digitalRead(btnMode)==1)
      {
        
        FadeToColor(1000, PWMRANGE-1,0,0); //Flash 5 times
        i++;
      }
      if(i==5) 
      {
        Serial.println("Reseting eeprom");
        ClearEeprom();
        FadeToColor(200, 0,PWMRANGE-1,0); //Pulse green to confirm eeprom reset
        iAutoMode = 2;
      }
          
    }
  }
  if (iAutoMode ==2)
  {
    //We're in random auto mode: the one that picks random patterns
    if (btnModeStatus==1) AssignRandomPotValues();
    if (btnMemStatus==1) AssignRandomPotValues();
    if (btnMemStatus==2) 
    {
      FadeToColor(1000, 0,PWMRANGE-1,0);  
      StoreNewPattern();
    }
  }
  else if (iAutoMode ==0)
  {
    //We're in manual mode
    if (btnModeStatus==1) 
    {  
       //FadeToColor(1000, PWMRANGE-1,0,0);
       NextMode();
    }
    if (btnModeStatus==2) 
    {  
      FadeToColor(1000, PWMRANGE-1,PWMRANGE-1,PWMRANGE-1);  
      AddColor();
    }
    if (btnMemStatus==2) 
    {
      FadeToColor(1000, 0,PWMRANGE-1,0);  
      StoreNewPattern();
    }
      
  }
}



void AddColor()
{
  if(iNbColor <= 3)
  {
    iRefColor[iNbColor] = iRefColor[0];
    iBrightness[iNbColor] = iBrightness[0];
    iNbColor++;
  }
  else 
  {
    iNbColor = 1;
  }
}
void ReadPots()
{
    iRefColor[0] = CalibratePot(analogRead(5), 6, 932) * 3 * 4;
    iBrightness[0] = (1023 - CalibratePot(analogRead(4), 6, 932));
    PotColorRandomness  = CalibratePot(analogRead(3), 6, 932);
    PotCycleSpeed = (CalibratePot(analogRead(2), 6, 932) / 4)+2;
}

int CalibratePot(int iValue, int iMin, int iMax)
{
  float Percentage = (float)(iValue - iMin) / (float)(iMax - iMin);
  if (Percentage >1) Percentage =1;
  if (Percentage <0) Percentage =0;
  return (Percentage * 1024);
}

void NextMode()
{
  //Goes to next Cycle Mode 
  CycleMode += 1;
  if (CycleMode >4) CycleMode=0;
  
}
//---------------------------------------------------------------------------------------------------------------------------------------
void FinishAllCycles()
{
  for(int i=0; i<NBLEDS; i++)
  currentFrame[i] = cycleNbFrame[i];
}

void GimmePureColor(int &iSpot, int &R, int &G, int &B)
{
           if(iSpot >= PWMRANGE*3) iSpot %= PWMRANGE*3;
           if(iSpot < 0) iSpot = (PWMRANGE*3) - (abs(iSpot) % (PWMRANGE*3));
           
           int x = abs(iSpot % PWMRANGE);
           
           if (iSpot <PWMRANGE){
           //Red to yellow
                  R = PWMRANGE - (1 + x);
                  G = x;
                  B = 0;
           }
           else if (iSpot <PWMRANGE*2)
           {
           //Green to tuquoise
                  R = 0;
                  G = PWMRANGE - (1 + x);
                  B = x;
           }else if (iSpot <PWMRANGE*3)
           {
                  R = x;
                  G = 0;
                  B = PWMRANGE - (1 + x);
           }     
}
void calcFrame(int i) {
//Calculates the color of the LED for the next frame (based on mode)
  if (currentFrame[i] >= cycleNbFrame[i])
  {
    StartNewCycle(i);
  }
  
  if (CycleMode ==0)
  {
    //Just flashing
    if(currentFrame[i] <= cycleNbFrame[i] /2)
    {
      curR[i] = toR[i];
      curG[i] = toG[i];
      curB[i] = toB[i];
    }
    else
    {
      curR[i] = 0;
      curG[i] = 0;
      curB[i] = 0;
    }
  }  
  else if (CycleMode ==1)
  {
      //Fading in then go out
      float perc = currentFrame[i] / (float)cycleNbFrame[i];
      curR[i] = toR[i] * perc;
      curG[i] = toG[i] * perc;
      curB[i] = toB[i] * perc;
  }
  else if (CycleMode ==2)
  { 
      //Fading in then fade out
      float perc =  sin((((float)currentFrame[i] / (float)cycleNbFrame[i])) * 3.1418);
      
      curR[i] = toR[i] * perc;
      curG[i] = toG[i] * perc;
      curB[i] = toB[i] * perc;
  }
  else if (CycleMode ==3)
  {
      //Fading from a color to another
      float perc = (float)currentFrame[i] / (float)cycleNbFrame[i];

      curR[i] = origR[i] +  (float(toR[i] - origR[i]) * perc);
      curG[i] = origG[i] +  (float(toG[i] - origG[i]) * perc);
      curB[i] = origB[i] +  (float(toB[i] - origB[i]) * perc);

  }
  else if (CycleMode ==4)
  {
      int iRange = ((float)PotColorRandomness / 1023) * (PWMRANGE * 3); 
      float perc = (float)currentFrame[i] / (float)cycleNbFrame[i];
      int iMyColor = iRefColor[0] + ((perc - .5) * iRange);
      
      GimmePureColor(iMyColor, curR[i], curG[i], curB[i]);
  }
    
  currentFrame[i]++;
}
//---------------------------------------------------------------------------------------------------------------------------------------

void ClearCurRGB()
{
  for(int i=0; i<NBLEDS; i++)
  {
    curR[i] = 0;
    curG[i] = 0;
    curB[i] = 0;
  }
}

//---------------------------------------------------------------------------------------------------------------------------------------
void StartNewCycle(int i)
{
  currentFrame[i] = 0;

  cycleNbFrame[i] = (float)PotCycleSpeed / 2;
  //Adding 20% randomness
  cycleNbFrame[i] += random((int)((float)PotCycleSpeed * 0.20));
 
     //Fade from a color to another
    //Assign a to color
    origR[i] = toR[i];    
    origG[i] = toG[i];
    origB[i] = toB[i];

  AssignPureRandomColor(i);
}
//---------------------------------------------------------------------------------------------------------------------------------------
void AssignPureRandomColor(int i)
{
           //randomSeed(millis());
           //int iPureColor = random(6 * PWMRANGE);
           int x=0;
           int iColorNumber = random(iNbColor);
           int iPureColor = iRefColor[iColorNumber];
           int iCurBrightness = iBrightness[iColorNumber];
           
           
             //Adding randomness
             x = random((1.5 * PWMRANGE) * ((float)PotColorRandomness/1023));
             if (random(2) ==0)
               x = -x;      
             iPureColor += x;
             
             if (iPureColor >= 3 * PWMRANGE)
             {
                 iPureColor -= 3 * PWMRANGE;
             }else if (iPureColor <0)
             {
                 iPureColor = (3 * PWMRANGE) + iPureColor;
             }
           
           
           GimmePureColor(iPureColor, toR[i], toG[i], toB[i]);

           if ( iCurBrightness > 612)
           {
             float fRange = 1024-612;
             toR[i] += (float)((PWMRANGE-1) - toR[i]) * ((float)( iCurBrightness - 612) / fRange);
             toG[i] += (float)((PWMRANGE-1) - toG[i]) * ((float)( iCurBrightness - 612) / fRange);
             toB[i] += (float)((PWMRANGE-1) - toB[i]) * ((float)( iCurBrightness - 612) / fRange);
             
             //float fAdj = (float)PWMRANGE / (float)(toR[i] + toG[i] + toB[i]) ;
             //toR[i] *= fAdj;
             //toG[i] *= fAdj;
             //toB[i] *= fAdj;
             
           }
           else if ( iCurBrightness < 412)
           {
             toR[i] = toR[i] * ((float) iCurBrightness / 412);
             toG[i] = toG[i] * ((float) iCurBrightness / 412);
             toB[i] = toB[i] * ((float) iCurBrightness / 412);
           }
           
}

//---------------------------------------------------------------------------------------------------------------------------------------
void AssignRandomColor(int i)
{
    toR[i] = random((int)((float)PWMRANGE * 0.7));
    toG[i] = random(PWMRANGE);
    toB[i] = random(PWMRANGE);
}
void DisplayLEDs()
{
  leds.clear();
  for(int i=0; i<16; i++)
  {
       leds.setLED(i,      curR[i]);
       leds.setLED(i+16,   curG[i]);
       leds.setLED(i+32,   curB[i]);
       
       leds.setLED(i+48,      curR[i]);
       leds.setLED(i+16+48,   curG[i]);
       leds.setLED(i+32+48,   curB[i]);
       
       leds.setLED(i+96,      curR[i]);
       leds.setLED(i+16+96,   curG[i]);
       leds.setLED(i+32+96,   curB[i]);
  }


  leds.display();
}
