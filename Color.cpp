
void Color_Set(Color * c, int _r, int _g, int _b)
{
  (*c).r = _r;
  (*c).g = _g;
  (*c).b = _b;
}

void Color_Hue(Color * c, int Hue)
{
           if(Hue >= PWMRANGE*3) Hue %= PWMRANGE*3;
           if(Hue < 0) Hue = (PWMRANGE*3) - (abs(Hue) % (PWMRANGE*3));
           
           int x = abs(Hue % PWMRANGE);
           
           if (iSpot <PWMRANGE){
           //Red to yellow
                  (*c).r = PWMRANGE - (1 + x);
                  (*c).g = x;
                  (*c).b = 0;
           }
           else if (iSpot <PWMRANGE*2)
           {
           //Green to tuquoise
                  (*c).r = 0;
                  (*c).g = PWMRANGE - (1 + x);
                  (*c).b = x;
           }else if (iSpot <PWMRANGE*3)
           {
                  (*c).r = x;
                  (*c).g = 0;
                  (*c).b = PWMRANGE - (1 + x);
           }     
}

int Color_ValBetween(int val1, int val2, int nom, int denom)
{
  return (((val2 - val1) * nom) / denom) + val1
}

void Color_Between(Color * c1, Color * c2, int nom, int denom)
{
  (*c1.r) = Color_ValBetween((*c1.r), (*c2.r), nom, denom);
  (*c1.g) = Color_ValBetween((*c1.g), (*c2.g), nom, denom);
  (*c1.b) = Color_ValBetween((*c1.b), (*c2.b), nom, denom);
}
