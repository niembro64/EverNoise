#ifndef BN_PEAK_PROTECTOR_H
#define BN_PEAK_PROTECTOR_H
#include "BNLoudnessCoefficients.h"
#include <math.h>
#include <stdint.h>
#include <string.h>

// Two 50 ms box averages produce a continuous triangular gain ramp. A rolling
// minimum spans their complete support, so each contributing demand includes
// the delayed output sample. Smoothing cannot raise gain above its safe demand.
// 100 ms anticipation + 16-frame reconstruction delay. Both channels share gain.
enum { BNPeakSmooth = 2400, BNPeakSupport = 2 * (BNPeakSmooth - 1),
       BNPeakWindow = BNPeakSupport + 1, BNPeakDelay = BNPeakSupport + 16,
       BNPeakRing = BNPeakDelay + 1 };
typedef struct {
    double audio[2][BNPeakRing], history[2][33];
    double demands[BNPeakWindow + 1];
    uint64_t demandFrames[BNPeakWindow + 1];
    unsigned front, size, historyIndex, audioIndex, smoothIndex;
    double smooth1[BNPeakSmooth], smooth2[BNPeakSmooth], sum1, sum2;
    double released, gain;
    uint64_t frame;
} BNPeakProtector;

static inline void BNPeakReset(BNPeakProtector *p) {
    memset(p, 0, sizeof(*p));
    for (int n = 0; n < BNPeakSmooth; ++n) p->smooth1[n] = p->smooth2[n] = 1;
    p->sum1 = p->sum2 = BNPeakSmooth;
    p->released = p->gain = 1;
}

static inline void BNPeakProcess(BNPeakProtector *p, double left, double right,
                                  double *outLeft, double *outRight) {
    const double ceiling = 0.7079457843841379; // -3 dBFS; conversion reserve.
    const double release = 0.000002083331163195951; // 1-exp(-1/(48000*10)).
    p->history[0][p->historyIndex] = left;
    p->history[1][p->historyIndex] = right;
    double peak = 0;
    for (int channel = 0; channel < 2; ++channel) {
        // Include the exact, detector-aligned original sample as well as FIR.
        peak = fmax(peak, fabs(p->history[channel][(p->historyIndex + 33 - 16) % 33]));
        for (int phase = 0; phase < 4; ++phase) {
            double sample = 0;
            unsigned pos = p->historyIndex;
            for (int tap = 0; tap < 33; ++tap) {
                sample += BNTruePeakFIR[phase][tap] * p->history[channel][pos];
                pos = pos ? pos - 1 : 32;
            }
            peak = fmax(peak, fabs(sample));
        }
    }
    p->historyIndex = (p->historyIndex + 1) % 33;
    double demand = peak > ceiling ? ceiling / peak : 1;
    // Monotone minimum queue: amortized O(1), fixed storage, uint64 clock.
    while (p->size && p->frame - p->demandFrames[p->front] >= BNPeakWindow) {
        p->front = (p->front + 1) % (BNPeakWindow + 1); --p->size;
    }
    while (p->size) {
        unsigned back = (p->front + p->size - 1) % (BNPeakWindow + 1);
        if (p->demands[back] < demand) break;
        --p->size;
    }
    unsigned back = (p->front + p->size++) % (BNPeakWindow + 1);
    p->demands[back] = demand; p->demandFrames[back] = p->frame++;
    double minimum = p->demands[p->front];
    p->released = fmin(minimum, p->released + release * (1 - p->released));
    unsigned i = p->smoothIndex;
    p->sum1 += p->released - p->smooth1[i]; p->smooth1[i] = p->released;
    double first = p->sum1 / BNPeakSmooth;
    p->sum2 += first - p->smooth2[i]; p->smooth2[i] = first;
    p->gain = fmin(1, fmax(0, p->sum2 / BNPeakSmooth));
    p->smoothIndex = (i + 1) % BNPeakSmooth;
    p->audio[0][p->audioIndex] = left; p->audio[1][p->audioIndex] = right;
    unsigned read = (p->audioIndex + 1) % BNPeakRing;
    *outLeft = p->audio[0][read] * p->gain;
    *outRight = p->audio[1][read] * p->gain;
    p->audioIndex = read;
}
#endif
