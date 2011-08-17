#include "Color.h"
struct Globe {
  Color CurrentColor;
  Color FromColor;
  Color ToColor;
  int CycleDuration;
  int CyclePosition;
};

void Globe_Calc(Globe * G);

