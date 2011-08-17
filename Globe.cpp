//---------------------------------------------------------------------------------------------------------------------------------------
void Globe_StartNewCycle(Globe * G)
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

void Globe_Calc(Globe * G) {
//Calculates the color of the LED for the next frame (based on mode)
  if (currentFrame[i] >= cycleNbFrame[i])
  {
    StartNewCycle(i);
  }
  
  if (CycleMode ==CYCLE_MODE_FLASH)
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
  else if (CycleMode ==CYCLE_MODE_FADE_IN)
  {
      //Fading in then go out
      float perc = currentFrame[i] / (float)cycleNbFrame[i];
      curR[i] = toR[i] * perc;
      curG[i] = toG[i] * perc;
      curB[i] = toB[i] * perc;
  }
  else if (CycleMode ==CYCLE_MODE_FADE_IN_OUT)
  { 
      //Fading in then fade out
      float perc =  sin((((float)currentFrame[i] / (float)cycleNbFrame[i])) * 3.1418);
      
      curR[i] = toR[i] * perc;
      curG[i] = toG[i] * perc;
      curB[i] = toB[i] * perc;
  }
  else if (CycleMode == CYCLE_MODE_FADE_TO_NEXT)
  {
      //Fading from a color to another
      float perc = (float)currentFrame[i] / (float)cycleNbFrame[i];

      curR[i] = origR[i] +  (float(toR[i] - origR[i]) * perc);
      curG[i] = origG[i] +  (float(toG[i] - origG[i]) * perc);
      curB[i] = origB[i] +  (float(toB[i] - origB[i]) * perc);

  }
  else if (CycleMode ==CYCLE_MODE_PALETTE_ANIM)
  {
      int iRange = ((float)PotColorRandomness / 1023) * (PWMRANGE * 3); 
      float perc = (float)currentFrame[i] / (float)cycleNbFrame[i];
      int iMyColor = iRefColor[0] + ((perc - .5) * iRange);
      
      GimmePureColor(iMyColor, curR[i], curG[i], curB[i]);
  }
    
  currentFrame[i]++;
}
