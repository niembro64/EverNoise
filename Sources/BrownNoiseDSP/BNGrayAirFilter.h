#ifndef BN_GRAY_AIR_FILTER_H
#define BN_GRAY_AIR_FILTER_H

#include <math.h>

// The Gray preset combines the unchanged Brown source with this gentle air
// layer. It is a warm, hearing-shaped approximation, not a calibrated hearing
// inverse. Two high passes keep the sensitive midrange subdued; two low passes
// soften the top. Every stage is linear, stable, and has constant coefficients.
typedef struct {
    double highPassPole, lowPassPole;
    double low1, low2, highCut1, highCut2;
} BNGrayAirFilter;

static inline BNGrayAirFilter BNGrayAirCreate(double rate) {
    const double tau = 6.28318530717958647693;
    BNGrayAirFilter f = {0};
    f.highPassPole = exp(-tau * 5000.0 / rate);
    f.lowPassPole = exp(-tau * 10000.0 / rate);
    return f;
}

static inline double BNGrayAirProcess(BNGrayAirFilter *f, double input) {
    f->low1 = f->highPassPole * f->low1 + (1.0 - f->highPassPole) * input;
    double high1 = input - f->low1;
    f->low2 = f->highPassPole * f->low2 + (1.0 - f->highPassPole) * high1;
    double high2 = high1 - f->low2;
    f->highCut1 = f->lowPassPole * f->highCut1 + (1.0 - f->lowPassPole) * high2;
    f->highCut2 = f->lowPassPole * f->highCut2 + (1.0 - f->lowPassPole) * f->highCut1;
    // Each high-pass has impulse L1 = 2*p; each low-pass has L1 = 1.
    // At 48 kHz, this source's absolute bound is below 0.109. Even adding
    // full Brown (0.75), White (0.02), and Air stays below 0.879 before SRC.
    return f->highCut2 * 0.10;
}
#endif
