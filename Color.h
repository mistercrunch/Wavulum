struct Color {
  int r;
  int g;
  int b;
};

void Color_Set(Color * c, int _r, int _g, int _b);
void Color_Hue(Color * c, int Hue);
void Color_Between(Color * c1, Color * c2, int nom, int denom);

