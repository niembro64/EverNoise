#ifndef BN_MID_FILTER_H
#define BN_MID_FILTER_H

#include <math.h>
#include <stdint.h>

// A separate linear midrange layer. Four high passes isolate the bass bed;
// four low passes keep this control concentrated below the treble layer.
typedef struct {
    double highPassPole, lowPassPole, gain;
    double lows[4], highs[4];
} BNMidFilter;

static inline double BNMidBase(BNMidFilter *f, double input) {
    double value = input;
    for (int i = 0; i < 4; ++i) {
        f->lows[i] = f->highPassPole * f->lows[i] + (1 - f->highPassPole) * value;
        value -= f->lows[i];
    }
    for (int i = 0; i < 4; ++i) {
        f->highs[i] = f->lowPassPole * f->highs[i] + (1 - f->lowPassPole) * value;
        value = f->highs[i];
    }
    return value;
}

static inline BNMidFilter BNMidCreate(double rate) {
    const double tau = 6.28318530717958647693;
    BNMidFilter f = {0};
    f.highPassPole = exp(-tau * 600.0 / rate);
    f.lowPassPole = exp(-tau * 3000.0 / rate);
    BNMidFilter probe = f;
    double impulseSum = 0;
    for (uint32_t n = 0; n < (uint32_t)ceil(rate); ++n) {
        impulseSum += fabs(BNMidBase(&probe, n == 0 ? 1.0 : 0.0));
    }
    // Bound all future output from the remaining states. Downstream high-pass
    // L1 norms are <= 2; low-pass norms are 1. No runtime normalization/limiter.
    double tail = 0;
    for (int i = 0; i < 4; ++i) {
        tail += (1 << (3 - i)) * fabs(probe.lows[i]) * f.highPassPole / (1 - f.highPassPole);
        tail += fabs(probe.highs[i]) * f.lowPassPole / (1 - f.lowPassPole);
    }
    f.gain = 0.10 * (1 - 1e-7) / (impulseSum + tail);
    return f;
}

static inline double BNMidProcess(BNMidFilter *f, double input) {
    return BNMidBase(f, input) * f->gain;
}
#endif
