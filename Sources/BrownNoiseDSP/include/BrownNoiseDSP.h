#ifndef BROWN_NOISE_DSP_H
#define BROWN_NOISE_DSP_H

#include <AudioToolbox/AudioToolbox.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct BNGenerator BNGenerator;

typedef enum {
    BNSourceBrown = 0,
    BNSourceWhite = 1,
    BNSourceGrayAir = 2,
    BNSourceMid = 3
} BNSourceKind;

// Three band pickers independently adjust Brown, Mid, and GrayAir from 0 to 4.
// White and boolean selection remain available for historical audit comparisons.
double BNRateForSource(BNSourceKind kind);
BNGenerator *BNCreateSource(BNSourceKind kind, uint64_t seed, bool selected);
// Lock-free selection command, smoothed over 600 ms on the render thread.
void BNSetSelected(BNGenerator *generator, bool selected);
// Five levels: off, -18, -12, -6, 0 dB relative to the layer's fixed maximum.
// Equal 6 dB power-ratio steps for active levels; sample gain = 10^(dB/20).
// Level 0 is exact silence. Input is clamped to [0,4].
// Targets are lock-free integers; 600 ms smoothing runs on the audio thread.
void BNSetLevel(BNGenerator *generator, int level);

// Fixed rate for the deliberately band-limited source. The engine converts to
// the hardware format without changing the generator's state.
double BNSourceSampleRate(void);

// Allocate once, outside the render thread. A zero seed selects a nonzero default.
BNGenerator *BNCreate(double sampleRate, uint64_t seed);
void BNDestroy(BNGenerator *generator);

// Only call while rendering is stopped. Preserves the noise/filter state.
void BNBeginFadeIn(BNGenerator *generator);
// Lock-free commands; only the render thread changes envelope/filter state.
void BNSetPlaying(BNGenerator *generator, bool playing);
bool BNIsSilent(const BNGenerator *generator);
// Diagnostic only; does not affect generation or impose a duration limit.
uint64_t BNRenderedFrames(const BNGenerator *generator);

// These functions allocate nothing, acquire no locks, and perform no I/O.
// State belongs exclusively to the audio render thread while it is running.
void BNRenderMono(BNGenerator *generator, float *output, uint32_t frameCount);
void BNRenderAudioBuffers(BNGenerator *generator, AudioBufferList *buffers, uint32_t frameCount);

// A permanent pair of independently seeded/filtering sources. Mono duplicates
// the original left signal exactly; Stereo replaces the right with its own
// signal through a bounded one-second crossfade. Neither source is restarted.
typedef struct BNStereoGenerator BNStereoGenerator;
BNStereoGenerator *BNStereoCreateSource(BNSourceKind kind, uint64_t leftSeed,
                                      uint64_t rightSeed, bool stereoEnabled);
void BNStereoDestroy(BNStereoGenerator *generator);
void BNStereoSetEnabled(BNStereoGenerator *generator, bool enabled);
void BNStereoSetLevel(BNStereoGenerator *generator, int level);
void BNStereoSetPlaying(BNStereoGenerator *generator, bool playing);
// Only while stopped. Applies the saved mode and starts the usual audio fade.
void BNStereoBeginFadeIn(BNStereoGenerator *generator);
bool BNStereoIsSilent(const BNStereoGenerator *generator);
uint64_t BNStereoRenderedFrames(const BNStereoGenerator *generator);
// Planar and AudioBufferList variants share the exact production render path.
// Buffers contain Float32 PCM. One-channel output receives the original left;
// two-channel output receives left/right, including interleaved storage.
void BNStereoRender(BNStereoGenerator *generator, float *left, float *right, uint32_t frameCount);
void BNStereoRenderAudioBuffers(BNStereoGenerator *generator, AudioBufferList *buffers, uint32_t frameCount);

#endif
