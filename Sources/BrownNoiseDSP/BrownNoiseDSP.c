#include "BrownNoiseDSP.h"
#include "BNColorFilter.h"
#include "BNGrayAirFilter.h"
#include "BNMidFilter.h"
#include "BNComplementaryFilter.h"
#include <stdlib.h>
#include <stdatomic.h>

_Static_assert(ATOMIC_INT_LOCK_FREE == 2 && ATOMIC_LONG_LOCK_FREE == 2 &&
               ATOMIC_LLONG_LOCK_FREE == 2, "Audio atomics must be lock-free");

struct BNGenerator {
    _Atomic(uint64_t) renderedFrames;
    _Atomic(int) requestedPlaying;
    _Atomic(int) silent;
    _Atomic(int) requestedLevel;
    uint64_t randomState;
    BNSourceKind kind;
    BNColorFilter filter;
    BNGrayAirFilter airFilter;
    BNMidFilter midFilter;
    BNComplementaryFilter complementaryFilter;
    double sampleRate;
    double envelope, envelopeStart, envelopeTarget;
    uint32_t envelopePosition, envelopeLength;
    int observedPlaying;
    double selection, selectionStart, selectionTarget;
    uint32_t selectionPosition, selectionLength;
    int observedLevel;
};

double BNSourceSampleRate(void) { return 8000.0; }

double BNRateForSource(BNSourceKind kind) {
    switch (kind) {
        case BNSourceBrown: return BNSourceSampleRate();
        case BNSourceWhite: case BNSourceGrayAir: case BNSourceMid:
        case BNSourceComplementaryLow: case BNSourceComplementaryMid:
        case BNSourceComplementaryHigh: return 48000.0;
        default: return 0;
    }
}

BNGenerator *BNCreate(double sampleRate, uint64_t seed) {
    if (!isfinite(sampleRate) || sampleRate < 8000 || sampleRate > 384000) return NULL;
    BNGenerator *g = calloc(1, sizeof(BNGenerator));
    if (!g) return NULL;
    atomic_init(&g->renderedFrames, 0);
    atomic_init(&g->requestedPlaying, 1);
    atomic_init(&g->silent, 1);
    atomic_init(&g->requestedLevel, 4);
    g->kind = BNSourceBrown;
    g->randomState = seed ? seed : UINT64_C(0x9E3779B97F4A7C15);
    g->sampleRate = sampleRate;
    g->filter = BNColorCreate(sampleRate);
    BNBeginFadeIn(g);
    return g;
}

BNGenerator *BNCreateSource(BNSourceKind kind, uint64_t seed, bool selected) {
    double rate = BNRateForSource(kind);
    if (rate == 0) return NULL;
    BNGenerator *g = BNCreate(rate, seed);
    if (!g) return NULL;
    g->kind = kind;
    if (kind == BNSourceGrayAir) g->airFilter = BNGrayAirCreate(rate);
    if (kind == BNSourceMid) g->midFilter = BNMidCreate(rate);
    if (kind >= BNSourceComplementaryLow && kind <= BNSourceComplementaryHigh)
        g->complementaryFilter = BNComplementaryCreate((int)kind - BNSourceComplementaryLow);
    BNSetSelected(g, selected);
    BNBeginFadeIn(g);
    return g;
}

void BNDestroy(BNGenerator *g) { free(g); }

static inline double gainForLevel(int level) {
    // Off, then -18, -12, -6, 0 dB relative to this layer's fixed maximum.
    // Power ratios use 10^(dB/10); samples need their square root, 10^(dB/20).
    // Precomputed constants keep transcendental work out of the render thread.
    // requestedLevel is clamped by BNSetLevel before it reaches this lookup.
    static const double gains[5] = {
        0.0, 0.12589254117941673, 0.251188643150958, 0.5011872336272722, 1.0
    };
    return gains[level];
}

void BNBeginFadeIn(BNGenerator *g) {
    // Only while rendering is stopped. Preserve noise and filter state.
    g->envelope = g->envelopeStart = 0;
    g->envelopeTarget = 1;
    g->envelopePosition = 0;
    g->envelopeLength = (uint32_t)(g->sampleRate * 0.75);
    g->observedPlaying = 1;
    atomic_store_explicit(&g->requestedPlaying, 1, memory_order_relaxed);
    atomic_store_explicit(&g->silent, 1, memory_order_relaxed);
    // A selection made while paused should be the only sound on restart.
    g->observedLevel = atomic_load_explicit(&g->requestedLevel, memory_order_relaxed);
    g->selection = g->selectionStart = g->selectionTarget = gainForLevel(g->observedLevel);
    g->selectionPosition = g->selectionLength = 0;
}

void BNSetSelected(BNGenerator *g, bool selected) {
    BNSetLevel(g, selected ? 4 : 0);
}

void BNSetLevel(BNGenerator *g, int level) {
    int bounded = level < 0 ? 0 : (level > 4 ? 4 : level);
    atomic_store_explicit(&g->requestedLevel, bounded, memory_order_relaxed);
}

void BNSetPlaying(BNGenerator *g, bool playing) {
    atomic_store_explicit(&g->requestedPlaying, playing, memory_order_relaxed);
}

bool BNIsSilent(const BNGenerator *g) {
    return atomic_load_explicit(&g->silent, memory_order_relaxed) != 0;
}

uint64_t BNRenderedFrames(const BNGenerator *g) {
    return atomic_load_explicit(&g->renderedFrames, memory_order_relaxed);
}

static inline void synchronizeEnvelope(BNGenerator *g) {
    int level = atomic_load_explicit(&g->requestedLevel, memory_order_relaxed);
    if (level != g->observedLevel) {
        g->observedLevel = level;
        g->selectionStart = g->selection;
        g->selectionTarget = gainForLevel(level);
        g->selectionPosition = 0;
        g->selectionLength = (uint32_t)(g->sampleRate * 0.6);
    }
    int playing = atomic_load_explicit(&g->requestedPlaying, memory_order_relaxed);
    if (playing == g->observedPlaying) return;
    g->observedPlaying = playing;
    g->envelopeStart = g->envelope;
    g->envelopeTarget = playing ? 1.0 : 0.0;
    g->envelopePosition = 0;
    g->envelopeLength = (uint32_t)(g->sampleRate * (playing ? 0.25 : 0.08));
}

static inline float nextSample(BNGenerator *g) {
    uint64_t x = g->randomState;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    g->randomState = x;
    uint64_t random = x * UINT64_C(2685821657736338717);
    // Midpoint quantization is symmetric about zero and bounded by one.
    double white = ((double)(random >> 40) + 0.5) * (2.0 / 16777216.0) - 1.0;
    double colored;
    switch (g->kind) {
        case BNSourceWhite: colored = white * 0.02; break;
        case BNSourceGrayAir: colored = BNGrayAirProcess(&g->airFilter, white); break;
        case BNSourceMid: colored = BNMidProcess(&g->midFilter, white); break;
        case BNSourceComplementaryLow: case BNSourceComplementaryMid:
        case BNSourceComplementaryHigh:
            colored = BNComplementaryProcess(&g->complementaryFilter, white); break;
        default: colored = BNColorProcess(&g->filter, white); break;
    }
    double sample = colored * g->envelope * g->selection;
    if (g->envelopePosition < g->envelopeLength) {
        double t = (double)++g->envelopePosition / g->envelopeLength;
        double smooth = t * t * (3.0 - 2.0 * t);
        g->envelope = g->envelopeStart + (g->envelopeTarget - g->envelopeStart) * smooth;
    }
    if (g->selectionPosition < g->selectionLength) {
        double t = (double)++g->selectionPosition / g->selectionLength;
        double smooth = t * t * (3.0 - 2.0 * t);
        g->selection = g->selectionStart + (g->selectionTarget - g->selectionStart) * smooth;
    }
    return (float)sample;
}

static inline void finishBuffer(BNGenerator *g, uint32_t count) {
    atomic_fetch_add_explicit(&g->renderedFrames, count, memory_order_relaxed);
    atomic_store_explicit(&g->silent, g->envelope == 0 && g->envelopeTarget == 0,
                          memory_order_relaxed);
}

void BNRenderMono(BNGenerator *g, float *output, uint32_t frameCount) {
    synchronizeEnvelope(g);
    for (uint32_t frame = 0; frame < frameCount; ++frame) output[frame] = nextSample(g);
    finishBuffer(g, frameCount);
}

void BNRenderAudioBuffers(BNGenerator *g, AudioBufferList *buffers, uint32_t frameCount) {
    synchronizeEnvelope(g);
    for (uint32_t frame = 0; frame < frameCount; ++frame) {
        float sample = nextSample(g);
        for (uint32_t b = 0; b < buffers->mNumberBuffers; ++b) {
            AudioBuffer *buffer = &buffers->mBuffers[b];
            float *data = buffer->mData;
            if (!data) continue;
            for (uint32_t channel = 0; channel < buffer->mNumberChannels; ++channel) {
                data[frame * buffer->mNumberChannels + channel] = sample;
            }
        }
    }
    finishBuffer(g, frameCount);
}

struct BNStereoGenerator {
    BNGenerator *left, *right;
    _Atomic(int) requestedStereo;
    int observedStereo;
    double width, widthStart, widthTarget;
    uint32_t widthPosition, widthLength;
};

BNStereoGenerator *BNStereoCreateSource(BNSourceKind kind, uint64_t leftSeed,
                                      uint64_t rightSeed, bool stereoEnabled) {
    BNStereoGenerator *g = calloc(1, sizeof(BNStereoGenerator));
    if (!g) return NULL;
    if (!leftSeed) leftSeed = UINT64_C(0x9E3779B97F4A7C15);
    if (!rightSeed || rightSeed == leftSeed) {
        rightSeed = leftSeed ^ UINT64_C(0xD1B54A32D192ED03);
        if (!rightSeed) rightSeed = UINT64_C(0x94D049BB133111EB);
    }
    g->left = BNCreateSource(kind, leftSeed, false);
    g->right = BNCreateSource(kind, rightSeed, false);
    if (!g->left || !g->right) { BNStereoDestroy(g); return NULL; }
    atomic_init(&g->requestedStereo, stereoEnabled);
    BNStereoBeginFadeIn(g);
    return g;
}

void BNStereoDestroy(BNStereoGenerator *g) {
    if (!g) return;
    BNDestroy(g->left); BNDestroy(g->right); free(g);
}

void BNStereoSetEnabled(BNStereoGenerator *g, bool enabled) {
    atomic_store_explicit(&g->requestedStereo, enabled, memory_order_relaxed);
}

void BNStereoSetLevel(BNStereoGenerator *g, int level) {
    BNSetLevel(g->left, level);
    // One atomic command per pair prevents a control update between the two
    // channel reads. synchronizeStereo copies the resulting envelope state.
}

void BNStereoSetPlaying(BNStereoGenerator *g, bool playing) {
    BNSetPlaying(g->left, playing);
}

static inline void copyStereoCommands(BNStereoGenerator *g) {
    BNSetLevel(g->right, atomic_load_explicit(&g->left->requestedLevel, memory_order_relaxed));
    BNSetPlaying(g->right, atomic_load_explicit(&g->left->requestedPlaying, memory_order_relaxed));
}

void BNStereoBeginFadeIn(BNStereoGenerator *g) {
    copyStereoCommands(g);
    BNBeginFadeIn(g->left); BNBeginFadeIn(g->right);
    g->observedStereo = atomic_load_explicit(&g->requestedStereo, memory_order_relaxed);
    g->width = g->widthStart = g->widthTarget = g->observedStereo ? 1 : 0;
    g->widthPosition = g->widthLength = 0;
}

bool BNStereoIsSilent(const BNStereoGenerator *g) {
    return BNIsSilent(g->left) && BNIsSilent(g->right);
}

uint64_t BNStereoRenderedFrames(const BNStereoGenerator *g) {
    return BNRenderedFrames(g->left);
}

static inline void synchronizeStereo(BNStereoGenerator *g) {
    synchronizeEnvelope(g->left);
    // Reuse the exact same control snapshot for both channels, even if a main-
    // thread command arrives during this buffer's synchronization.
    g->right->observedLevel = g->left->observedLevel;
    g->right->selection = g->left->selection;
    g->right->selectionStart = g->left->selectionStart;
    g->right->selectionTarget = g->left->selectionTarget;
    g->right->selectionPosition = g->left->selectionPosition;
    g->right->selectionLength = g->left->selectionLength;
    g->right->observedPlaying = g->left->observedPlaying;
    g->right->envelope = g->left->envelope;
    g->right->envelopeStart = g->left->envelopeStart;
    g->right->envelopeTarget = g->left->envelopeTarget;
    g->right->envelopePosition = g->left->envelopePosition;
    g->right->envelopeLength = g->left->envelopeLength;
    int enabled = atomic_load_explicit(&g->requestedStereo, memory_order_relaxed);
    if (enabled == g->observedStereo) return;
    g->observedStereo = enabled;
    g->widthStart = g->width;
    g->widthTarget = enabled ? 1 : 0;
    g->widthPosition = 0;
    g->widthLength = (uint32_t)g->left->sampleRate;
}

static inline void nextStereoSample(BNStereoGenerator *g, float *left, float *right) {
    float a = nextSample(g->left), b = nextSample(g->right);
    *left = a;
    // Convex blending cannot exceed the approved source bound. No limiter,
    // boost, or normalization is used. Intermediate right-channel power can
    // dip by up to 3 dB; settled mono/stereo have identical per-channel power.
    *right = g->width == 0 ? a : (g->width == 1 ? b :
        (float)((1 - g->width) * a + g->width * b));
    if (g->widthPosition < g->widthLength) {
        double t = (double)++g->widthPosition / g->widthLength;
        double smooth = t * t * t * (t * (6 * t - 15) + 10);
        g->width = g->widthStart + (g->widthTarget - g->widthStart) * smooth;
    }
}

static inline void finishStereoBuffer(BNStereoGenerator *g, uint32_t count) {
    finishBuffer(g->left, count); finishBuffer(g->right, count);
}

void BNStereoRender(BNStereoGenerator *g, float *left, float *right, uint32_t frameCount) {
    synchronizeStereo(g);
    for (uint32_t frame = 0; frame < frameCount; ++frame)
        nextStereoSample(g, &left[frame], &right[frame]);
    finishStereoBuffer(g, frameCount);
}

void BNStereoRenderAudioBuffers(BNStereoGenerator *g, AudioBufferList *buffers, uint32_t frameCount) {
    synchronizeStereo(g);
    for (uint32_t frame = 0; frame < frameCount; ++frame) {
        float left, right;
        nextStereoSample(g, &left, &right);
        uint32_t outputChannel = 0;
        for (uint32_t b = 0; b < buffers->mNumberBuffers; ++b) {
            AudioBuffer *buffer = &buffers->mBuffers[b];
            float *data = buffer->mData;
            for (uint32_t channel = 0; channel < buffer->mNumberChannels; ++channel, ++outputChannel)
                if (data) data[frame * buffer->mNumberChannels + channel] = outputChannel == 1 ? right : left;
        }
    }
    finishStereoBuffer(g, frameCount);
}
