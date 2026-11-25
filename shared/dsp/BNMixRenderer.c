#include "BrownNoiseDSP.h"
#include "BNComplementaryFilter.h"
#include "BNPeakProtector.h"
#include <stdlib.h>
#include <stdatomic.h>

_Static_assert(ATOMIC_INT_LOCK_FREE == 2 && ATOMIC_LLONG_LOCK_FREE == 2,
               "Render commands must be lock free");
_Static_assert(__atomic_always_lock_free(sizeof(double), 0), "Diagnostic atomics must be lock free");

typedef struct { double value, start, target; uint32_t position, length; } BNRamp;
static void rampTo(BNRamp *r, double target, unsigned length) {
    r->start = r->value; r->target = target; r->position = 0; r->length = length;
}
static void rampReset(BNRamp *r, double value) {
    *r = (BNRamp){ .value = value, .start = value, .target = value };
}
static inline void advance(BNRamp *r) {
    if (r->position >= r->length) return;
    double t = (double)++r->position / r->length;
    r->value = r->start + (r->target - r->start) * (t*t*(3-2*t));
    if (r->position == r->length) r->value = r->target;
}

struct BNMixGenerator {
    _Atomic(int) levels, stereo, offset, playing, silent;
    _Atomic(uint64_t) renderedFrames;
    _Atomic(double) publishedPower, publishedSlowGain, publishedProtection;
    int observedLevels, observedStereo, observedOffset, observedPlaying;
    uint64_t random[2][3];
    BNComplementaryFilter filters[2][3];
    BNSecondOrderState weighting[2][2];
    double inverseBandRMS[3], power, slowGain, meterAlpha, correctionAlpha;
    double offsetGains[22];
    BNRamp shape[3], audible, width, level, playback;
    BNPeakProtector peak;
};

static int clampLevel(int x) { return x < 0 ? 0 : x >= BNMixLevelCount ? BNMixLevelCount - 1 : x; }
double BNMixAmplitudeForLevel(int level) {
    // Keep the original four nonzero weights bit-for-bit. Only the -30 dB
    // choice is new; filters, normalization and peak protection are unchanged.
    static const double weights[BNMixLevelCount] = {
        0, .03162277660168379, .12589254117941673, .251188643150958, .5011872336272722, 1
    };
    return weights[clampLevel(level)];
}
static uint64_t splitMix(uint64_t *state) {
    uint64_t z = (*state += UINT64_C(0x9E3779B97F4A7C15));
    z = (z ^ (z >> 30)) * UINT64_C(0xBF58476D1CE4E5B9);
    z = (z ^ (z >> 27)) * UINT64_C(0x94D049BB133111EB);
    z ^= z >> 31;
    return z ? z : UINT64_C(0xD1B54A32D192ED03);
}
static inline double noise(BNMixGenerator *g, int channel, int band) {
    uint64_t x = g->random[channel][band];
    x ^= x >> 12; x ^= x << 25; x ^= x >> 27;
    g->random[channel][band] = x;
    uint64_t random = x * UINT64_C(2685821657736338717);
    double white = ((double)(random >> 40) + .5) * (2.0 / 16777216.0) - 1;
    return BNComplementaryProcess(&g->filters[channel][band], white);
}

// Unit vector in K-weighted power coordinates. A common multiplier applied to
// all three user weights cancels exactly. Interpolated vectors are renormalized
// on every sample, preventing crossfade dips without feedback chasing a change.
static void setShape(BNMixGenerator *g, int packed, bool immediate) {
    double q[3], energy = 0;
    for (int b = 0; b < 3; ++b) {
        q[b] = BNMixAmplitudeForLevel((packed >> (3*b)) & 7) / g->inverseBandRMS[b];
        energy += q[b]*q[b];
    }
    bool audible = energy > 0;
    if (audible) {
        double inverse = 1/sqrt(energy);
        for (int b = 0; b < 3; ++b) {
            double target = q[b] * inverse;
            if (immediate || g->audible.value == 0) rampReset(&g->shape[b], target);
            else rampTo(&g->shape[b], target, 28800);
        }
    }
    // Do not normalize a fade to silence back up to full volume.
    if (immediate) rampReset(&g->audible, audible ? 1 : 0);
    else rampTo(&g->audible, audible ? 1 : 0, 28800);
}

BNMixGenerator *BNMixCreate(uint64_t seed) {
    BNMixGenerator *g = calloc(1, sizeof(*g));
    if (!g) return NULL;
    atomic_init(&g->levels, 3 | (3 << 3) | (2 << 6));
    atomic_init(&g->stereo, 1); atomic_init(&g->offset, 0);
    atomic_init(&g->playing, 1); atomic_init(&g->silent, 1);
    atomic_init(&g->renderedFrames, 0);
    atomic_init(&g->publishedPower, 1); atomic_init(&g->publishedSlowGain, 1);
    atomic_init(&g->publishedProtection, 1);
    g->power = g->slowGain = 1;
    g->meterAlpha = -expm1(-1.0/(48000*30));
    g->correctionAlpha = -expm1(-1.0/(48000*60));
    for (int b = 0; b < 3; ++b) g->inverseBandRMS[b] = 1/sqrt(BNBandKPower[b]);
    for (int dB = -18; dB <= 3; ++dB)
        g->offsetGains[dB+18] = sqrt(pow(10, (-20 + dB + .691)/10) / 2);
    rampReset(&g->shape[0], 1);
    for (int ch = 0; ch < 2; ++ch) for (int b = 0; b < 3; ++b) {
        g->random[ch][b] = splitMix(&seed);
        g->filters[ch][b] = BNComplementaryCreate(b);
        // Pre-roll only at allocation, outside the callback, so the first fade
        // starts with settled noise. No repeated audio or timer is introduced.
        for (int n = 0; n < 48000; ++n) (void)noise(g, ch, b);
    }
    BNMixBeginFadeIn(g);
    return g;
}
void BNMixDestroy(BNMixGenerator *g) { free(g); }
void BNMixSetLevels(BNMixGenerator *g, int low, int mid, int high) {
    atomic_store_explicit(&g->levels, clampLevel(low) | (clampLevel(mid)<<3) | (clampLevel(high)<<6), memory_order_relaxed);
}
void BNMixSetStereo(BNMixGenerator *g, bool stereo) {
    atomic_store_explicit(&g->stereo, stereo, memory_order_relaxed);
}
void BNMixSetOffsetDB(BNMixGenerator *g, int offset) {
    atomic_store_explicit(&g->offset, offset < -18 ? -18 : offset > 3 ? 3 : offset, memory_order_relaxed);
}
void BNMixSetPlaying(BNMixGenerator *g, bool playing) {
    atomic_store_explicit(&g->playing, playing, memory_order_relaxed);
}
void BNMixBeginFadeIn(BNMixGenerator *g) {
    g->observedLevels = atomic_load_explicit(&g->levels, memory_order_relaxed);
    g->observedStereo = atomic_load_explicit(&g->stereo, memory_order_relaxed);
    g->observedOffset = atomic_load_explicit(&g->offset, memory_order_relaxed);
    g->observedPlaying = 1;
    atomic_store_explicit(&g->playing, 1, memory_order_relaxed);
    atomic_store_explicit(&g->silent, 1, memory_order_relaxed);
    setShape(g, g->observedLevels, true);
    rampReset(&g->width, g->observedStereo ? 1 : 0);
    rampReset(&g->level, g->offsetGains[g->observedOffset+18]);
    rampReset(&g->playback, 0); rampTo(&g->playback, 1, 36000);
    BNPeakReset(&g->peak);
}
static void synchronize(BNMixGenerator *g) {
    int levels = atomic_load_explicit(&g->levels, memory_order_relaxed);
    if (levels != g->observedLevels) { g->observedLevels = levels; setShape(g, levels, false); }
    int stereo = atomic_load_explicit(&g->stereo, memory_order_relaxed);
    if (stereo != g->observedStereo) {
        g->observedStereo = stereo; rampTo(&g->width, stereo ? 1 : 0, 48000);
    }
    int offset = atomic_load_explicit(&g->offset, memory_order_relaxed);
    if (offset != g->observedOffset) {
        g->observedOffset = offset; rampTo(&g->level, g->offsetGains[offset+18], 144000);
    }
    int playing = atomic_load_explicit(&g->playing, memory_order_relaxed);
    if (playing != g->observedPlaying) {
        g->observedPlaying = playing; rampTo(&g->playback, playing ? 1 : 0, playing ? 12000 : 3840);
    }
}
static inline void next(BNMixGenerator *g, float *outLeft, float *outRight) {
    double energy = 0, coefficients[3];
    for (int b = 0; b < 3; ++b) energy += g->shape[b].value * g->shape[b].value;
    double inverse = energy > 1e-20 ? 1/sqrt(energy) : 0;
    for (int b = 0; b < 3; ++b) coefficients[b] = g->shape[b].value * inverse * g->inverseBandRMS[b];
    double x[2] = {0};
    for (int ch = 0; ch < 2; ++ch) for (int b = 0; b < 3; ++b) x[ch] += coefficients[b] * noise(g, ch, b);
    double w = g->width.value;
    x[1] = ((1-w)*x[0] + w*x[1]) / sqrt((1-w)*(1-w) + w*w);
    double power = 0;
    for (int ch = 0; ch < 2; ++ch) {
        double weighted = x[ch];
        for (int b = 0; b < 2; ++b) weighted = BNSecondOrderProcess(&g->weighting[ch][b], &BNKWeighting[b], weighted);
        power += .5 * weighted * weighted;
    }
    if (g->audible.value == 1 && g->playback.value == 1) {
        // Meter before protection/fades. Feedback must never fight a limiter,
        // fade or silence by turning the gain up. Correction stays within 1 dB.
        g->power += g->meterAlpha * (power - g->power);
        double correction = 1/sqrt(fmax(g->power, 1e-20));
        correction = fmin(1.1220184543019633, fmax(.8912509381337456, correction));
        g->slowGain += g->correctionAlpha * (correction - g->slowGain);
    }
    double gain = g->level.value * g->slowGain;
    double left, right;
    BNPeakProcess(&g->peak, x[0]*gain, x[1]*gain, &left, &right);
    double fade = g->playback.value * g->audible.value;
    *outLeft = (float)(left * fade); *outRight = (float)(right * fade);
    for (int b = 0; b < 3; ++b) advance(&g->shape[b]);
    advance(&g->width); advance(&g->level); advance(&g->audible); advance(&g->playback);
}
static void finish(BNMixGenerator *g, uint32_t frames) {
    atomic_fetch_add_explicit(&g->renderedFrames, frames, memory_order_relaxed);
    atomic_store_explicit(&g->silent, g->playback.value == 0 && g->playback.target == 0, memory_order_relaxed);
    atomic_store_explicit(&g->publishedPower, g->power, memory_order_relaxed);
    atomic_store_explicit(&g->publishedSlowGain, g->slowGain, memory_order_relaxed);
    atomic_store_explicit(&g->publishedProtection, g->peak.gain, memory_order_relaxed);
}
bool BNMixIsSilent(const BNMixGenerator *g) { return atomic_load_explicit(&g->silent, memory_order_relaxed); }
uint64_t BNMixRenderedFrames(const BNMixGenerator *g) { return atomic_load_explicit(&g->renderedFrames, memory_order_relaxed); }
BNMixMetrics BNMixReadMetrics(const BNMixGenerator *g) {
    return (BNMixMetrics){atomic_load_explicit(&g->publishedPower, memory_order_relaxed),
        atomic_load_explicit(&g->publishedSlowGain, memory_order_relaxed),
        atomic_load_explicit(&g->publishedProtection, memory_order_relaxed), BNMixRenderedFrames(g)};
}
void BNMixRender(BNMixGenerator *g, float *left, float *right, uint32_t frames) {
    synchronize(g);
    for (uint32_t n = 0; n < frames; ++n) next(g, &left[n], &right[n]);
    finish(g, frames);
}
#if defined(__APPLE__)
void BNMixRenderAudioBuffers(BNMixGenerator *g, AudioBufferList *buffers, uint32_t frames) {
    synchronize(g);
    for (uint32_t n = 0; n < frames; ++n) {
        float left, right; next(g, &left, &right);
        unsigned channel = 0;
        for (unsigned b = 0; b < buffers->mNumberBuffers; ++b) {
            AudioBuffer *buffer = &buffers->mBuffers[b];
            float *data = buffer->mData;
            for (unsigned c = 0; c < buffer->mNumberChannels; ++c, ++channel)
                if (data) data[n*buffer->mNumberChannels+c] = channel == 0 ? left : right;
        }
    }
    finish(g, frames);
}
#endif
