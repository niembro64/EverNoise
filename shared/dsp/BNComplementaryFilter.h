#ifndef BN_COMPLEMENTARY_FILTER_H
#define BN_COMPLEMENTARY_FILTER_H
#include "BNComplementaryCoefficients.h"

typedef struct { double z1, z2; } BNSecondOrderState;
typedef struct {
    double pink[6];
    BNSecondOrderState subsonic[BNSubsonicSections], ultrasonic, lowerSplit, upperSplit;
    int band;
} BNComplementaryFilter;

static inline double BNSecondOrderProcess(BNSecondOrderState *s,
                                          const BNSecondOrderCoefficients *c, double x) {
    double y = c->b0 * x + s->z1;
    s->z1 = c->b1 * x - c->a1 * y + s->z2;
    s->z2 = c->b2 * x - c->a2 * y;
    return y;
}

static inline BNComplementaryFilter BNComplementaryCreate(int band) {
    BNComplementaryFilter f = {0};
    f.band = band;
    return f;
}

// All three independently excited bands have the same common coloring/gain.
// Low = L200; Mid = H200*L2000; High = H200*H2000. Butterworth pairs obey
// |L|^2 + |H|^2 = 1, so the three power weights sum to one at every frequency.
// This is a linear, fixed-coefficient filter: no limiter, clipping, dynamic
// normalization, buffer-local state, allocation, locks, or transcendental work.
static inline double BNComplementaryColor(BNComplementaryFilter *f, double white) {
    double x = white;
    for (int i = 0; i < BNSubsonicSections; ++i)
        x = BNSecondOrderProcess(&f->subsonic[i], &BNSubsonic[i], x);
    for (int i = 0; i < 6; ++i) {
        const BNFirstOrderCoefficients *c = &BNPinkShelves[i];
        double y = c->b0 * x + f->pink[i];
        f->pink[i] = c->b1 * x - c->a1 * y;
        x = y;
    }
    return BNSecondOrderProcess(&f->ultrasonic, &BNUltrasonic, x);
}

static inline double BNComplementaryProcess(BNComplementaryFilter *f, double white) {
    double x = BNComplementaryColor(f, white);
    if (f->band == 0) {
        x = BNSecondOrderProcess(&f->lowerSplit, &BNLowPass200, x);
    } else {
        x = BNSecondOrderProcess(&f->lowerSplit, &BNHighPass200, x);
        x = BNSecondOrderProcess(&f->upperSplit,
                                f->band == 1 ? &BNLowPass2000 : &BNHighPass2000, x);
    }
    return x * BNComplementaryGain;
}
#endif
