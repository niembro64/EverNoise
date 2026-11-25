#ifndef BN_COLOR_FILTER_H
#define BN_COLOR_FILTER_H

#include <math.h>
#include <stdint.h>

// Linear coloring: no clipping, saturation, compression, block normalization,
// or automatic gain control. This header is also used by the signal audit.
typedef struct {
    double brownPole, highPassPole, lowPassPole, gain;
    double brown, low1, low2, highCut1, highCut2;
} BNColorFilter;

static inline double BNColorBase(BNColorFilter *f, double input) {
    f->brown = f->brownPole * f->brown + (1.0 - f->brownPole) * input;
    f->low1 = f->highPassPole * f->low1 + (1.0 - f->highPassPole) * f->brown;
    double high1 = f->brown - f->low1;
    f->low2 = f->highPassPole * f->low2 + (1.0 - f->highPassPole) * high1;
    return high1 - f->low2;
}

static inline BNColorFilter BNColorCreate(double rate) {
    const double tau = 6.28318530717958647693;
    BNColorFilter f = {0};
    f.brownPole = exp(-tau * 18.0 / rate);
    // Remove DC/sub-bass and soften the upper texture without resonant filters.
    f.highPassPole = exp(-tau * 35.0 / rate);
    f.lowPassPole = exp(-tau * 1400.0 / rate);

    // One constant gain from an impulse-response bound, calculated at creation.
    // For every excitation in [-1,1], |output| <= gain * sum(abs(impulse)).
    BNColorFilter probe = f;
    double impulseSum = 0;
    for (uint32_t n = 0; n < (uint32_t)ceil(rate); ++n) {
        impulseSum += fabs(BNColorBase(&probe, n == 0 ? 1.0 : 0.0));
    }
    // Bound the entire infinite tail from the three remaining filter states.
    double brownTail = fabs(probe.brown) * f.brownPole / (1.0 - f.brownPole);
    double low1Tail = fabs(probe.low1) * f.highPassPole / (1.0 - f.highPassPole);
    double low2Tail = fabs(probe.low2) * f.highPassPole / (1.0 - f.highPassPole);
    double tailBound = 4.0 * brownTail + 2.0 * low1Tail + low2Tail;
    // Each upper low-pass has positive coefficients summing to one and cannot
    // increase this bound. Leave extra margin for numerical rounding.
    f.gain = 0.75 * (1.0 - 1e-7) / (impulseSum + tailBound);
    return f;
}

static inline double BNColorProcess(BNColorFilter *f, double input) {
    double value = BNColorBase(f, input);
    f->highCut1 = f->lowPassPole * f->highCut1 + (1.0 - f->lowPassPole) * value;
    f->highCut2 = f->lowPassPole * f->highCut2 + (1.0 - f->lowPassPole) * f->highCut1;
    return f->highCut2 * f->gain;
}

#endif
