#include "SpectrumAnalysis.h"
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

struct BNSpectrum {
    FFTSetup fft;
    float samples[2][BNSpectrumFFTSize], window[BNSpectrumFFTSize];
    float real[BNSpectrumFFTSize], imaginary[BNSpectrumFFTSize];
    float power[BNSpectrumFFTSize/2+1], lower[BNSpectrumRows], upper[BNSpectrumRows];
    double windowEnergy;
    uint32_t index, filled, hop;
    uint64_t expectedFrame;
    bool hasClock;
};
BNSpectrum *BNSpectrumCreate(void) {
    BNSpectrum *s = calloc(1, sizeof(*s));
    if (!s) return NULL;
    s->fft = vDSP_create_fftsetup(15, kFFTRadix2);
    if (!s->fft) { free(s); return NULL; }
    for (int n = 0; n < BNSpectrumFFTSize; ++n) {
        double w = .5 - .5*cos(2*M_PI*n/BNSpectrumFFTSize); // periodic Hann
        s->window[n] = w; s->windowEnergy += w*w;
    }
    for (int row = 0; row < BNSpectrumRows; ++row) {
        s->lower[row] = 20*pow(1000, (row-.5)/(BNSpectrumRows-1.0)) / (48000.0/BNSpectrumFFTSize);
        s->upper[row] = 20*pow(1000, (row+.5)/(BNSpectrumRows-1.0)) / (48000.0/BNSpectrumFFTSize);
    }
    return s;
}
void BNSpectrumDestroy(BNSpectrum *s) { if (s) { vDSP_destroy_fftsetup(s->fft); free(s); } }
void BNSpectrumReset(BNSpectrum *s) {
    s->index = s->filled = s->hop = 0; s->hasClock = false;
    memset(s->power, 0, sizeof(s->power));
}
static void analyze(BNSpectrum *s, float *column) {
    memset(s->power, 0, sizeof(s->power));
    // Unscaled complex forward FFT, Hann energy normalization, one-sided PSD.
    // Averaging channel powers preserves stereo energy without phase cancellation.
    double scale = 1.0/(48000*s->windowEnergy);
    for (int ch = 0; ch < 2; ++ch) {
        for (int n = 0; n < BNSpectrumFFTSize; ++n)
            s->real[n] = s->samples[ch][(s->index+n)%BNSpectrumFFTSize] * s->window[n];
        memset(s->imaginary, 0, sizeof(s->imaginary));
        DSPSplitComplex z = {s->real, s->imaginary};
        vDSP_fft_zip(s->fft, &z, 1, 15, FFT_FORWARD);
        for (int k = 0; k <= BNSpectrumFFTSize/2; ++k) {
            double p = (double)s->real[k]*s->real[k] + (double)s->imaginary[k]*s->imaginary[k];
            s->power[k] += p*scale*((k == 0 || k == BNSpectrumFFTSize/2) ? .5 : 1);
        }
    }
    for (int row = 0; row < BNSpectrumRows; ++row) {
        double lo = s->lower[row], hi = s->upper[row], power = 0;
        if (hi-lo < 1) {
            double center = sqrt(lo*hi); int k = (int)center;
            power = s->power[k]*(1-(center-k)) + s->power[k+1]*(center-k);
        } else {
            for (int k = (int)floor(lo+.5); k <= (int)floor(hi+.5); ++k)
                power += s->power[k]*fmax(0, fmin(hi, k+.5)-fmax(lo, k-.5));
            power /= hi-lo;
        }
        column[row] = 10*log10(fmax(power, 1e-16));
    }
}
uint32_t BNSpectrumConsume(BNSpectrum *s, const BNCapturedFrame *frames, uint32_t count,
                          float *columns, uint64_t *endFrames, uint32_t capacity) {
    uint32_t produced = 0;
    for (uint32_t n = 0; n < count; ++n) {
        const BNCapturedFrame *f = &frames[n];
        if (s->hasClock && f->frame != s->expectedFrame) BNSpectrumReset(s);
        s->hasClock = true; s->expectedFrame = f->frame+1;
        s->samples[0][s->index] = f->left; s->samples[1][s->index] = f->right;
        s->index = (s->index+1)%BNSpectrumFFTSize;
        if (s->filled < BNSpectrumFFTSize) {
            ++s->filled;
            if (s->filled < BNSpectrumFFTSize) continue;
            s->hop = BNSpectrumHop;
        } else ++s->hop;
        if (s->hop >= BNSpectrumHop) {
            s->hop = 0;
            if (produced < capacity) {
                analyze(s, columns+produced*BNSpectrumRows);
                endFrames[produced++] = f->frame;
            }
        }
    }
    return produced;
}
void BNSpectrumCopyPower(const BNSpectrum *s, float *density) { memcpy(density, s->power, sizeof(s->power)); }
