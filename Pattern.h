#ifndef PATTERN
#define PATTERN

#define N_PATTERNS 3

typedef struct Pattern {
  char* name;
  uint16_t size;
  uint16_t lights[10];
} pattern;

pattern patterns[3];

void initPatterns() {
    pattern p1;
    pattern p2;
    pattern p3;

    p1.name = "Cross";
    p1.size = 5;
    p1.lights[0] = 10;
    p1.lights[1] = 8;
    p1.lights[2] = 6;
    p1.lights[3] = 4;
    p1.lights[4] = 2;

    p2.name = "Triangle";
    p2.size = 4;
    p2.lights[0] = 6;
    p2.lights[1] = 4;
    p2.lights[2] = 7;
    p2.lights[3] = 10;
    
    p3.name = "Letter M";
    p3.size = 7;
    p3.lights[0] = 10;
    p3.lights[1] = 9;
    p3.lights[2] = 8;
    p3.lights[3] = 6;
    p3.lights[4] = 4;
    p3.lights[5] = 3;
    p3.lights[6] = 2;
    
    patterns[0] = p1;
    patterns[1] = p2;
    patterns[2] = p3;
}

#endif
