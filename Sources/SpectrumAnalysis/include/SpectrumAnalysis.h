#ifndef SPECTRUM_ANALYSIS_H
#define SPECTRUM_ANALYSIS_H
#include <AudioToolbox/AudioToolbox.h>
#include <stdbool.h>
#include <stdint.h>

enum { BNSpectrumFFTSize = 32768, BNSpectrumHop = 2048,
       BNSpectrumRows = 512, BNCaptureCapacity = 65536,
       BNSpectrumSampleRate = 48000, BNSpectrumLowDecimation = 8,
       BNSpectrumFilterTaps = 257, BNSpectrumFilterDelay = 128,
       BNSpectrumWarmupFrames = BNSpectrumFFTSize * BNSpectrumLowDecimation + BNSpectrumFilterTaps - 1,
       BNSpectrumMinimumHz = 2, BNSpectrumMaximumHz = 48000,
       BNSpectrumNyquistHz = BNSpectrumSampleRate / 2 };
typedef struct BNCapture BNCapture;
typedef struct { float left, right; uint64_t frame; } BNCapturedFrame;
BNCapture *BNCaptureCreate(void);
void BNCaptureDestroy(BNCapture *capture);
void BNCaptureSetEnabled(BNCapture *capture, bool enabled);
// One producer: audio callback. Never allocates, locks, waits or performs FFTs.
void BNCaptureAudioBuffers(BNCapture *capture, const AudioBufferList *buffers, uint32_t frames);
void BNCapturePlanar(BNCapture *capture, const float *left, const float *right, uint32_t frames);
// One consumer: analysis worker. A full buffer drops visual samples, not sound.
uint32_t BNCaptureRead(BNCapture *capture, BNCapturedFrame *output, uint32_t capacity);
void BNCaptureDiscard(BNCapture *capture);
uint64_t BNCapturePublishedFrames(const BNCapture *capture);
uint64_t BNCaptureDroppedFrames(const BNCapture *capture);

typedef struct BNSpectrum BNSpectrum;
BNSpectrum *BNSpectrumCreate(void);
void BNSpectrumDestroy(BNSpectrum *spectrum);
void BNSpectrumReset(BNSpectrum *spectrum);
// Consumer only. Each column has 512 logarithmic rows, 2 Hz to 48 kHz,
// in dBFS/Hz. Rows above the 24 kHz source Nyquist limit are NAN (unmeasured).
// Stereo POWER is averaged; opposite-phase channels never cancel visually.
// A discontinuous sample clock resets the window instead of splicing audio.
// The low-frequency window uses 8x decimation after a 257-tap anti-alias FIR.
// endFrames refers to the shared, FIR-delay-compensated sample endpoint.
uint32_t BNSpectrumConsume(BNSpectrum *spectrum, const BNCapturedFrame *frames, uint32_t count,
                          float *columns, uint64_t *endFrames, uint32_t capacity);
// Linear one-sided PSD for calibration/tests, N/2+1 bins, last complete window.
void BNSpectrumCopyPower(const BNSpectrum *spectrum, float *density);
void BNSpectrumCopyLowPower(const BNSpectrum *spectrum, float *density);
double BNSpectrumRowFrequency(uint32_t row);
// Analysis-only evaluation of the production crossover coefficients at equal
// input gains. Common pink coloring/rolloffs cancel in these normalized weights.
void BNSpectrumReferenceWeights(double frequencyHz, double weights[3]);
#endif
