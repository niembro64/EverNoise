#include "SpectrumAnalysis.h"
#include "BNSpectrumDecimation.h"
// Use the generator's immutable coefficients for stable reference colors.
#include "../BrownNoiseDSP/BNComplementaryCoefficients.h"
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

enum { FullRingSize = BNSpectrumFFTSize + BNSpectrumFilterDelay };
struct BNSpectrum {
    FFTSetup fft;
    float samples[2][FullRingSize], lowSamples[2][BNSpectrumFFTSize];
    float filterHistory[2][2*BNSpectrumFilterTaps], window[BNSpectrumFFTSize];
    float real[BNSpectrumFFTSize], imaginary[BNSpectrumFFTSize];
    float power[BNSpectrumFFTSize/2+1], lowPower[BNSpectrumFFTSize/2+1];
    double lower[BNSpectrumRows], upper[BNSpectrumRows], frequency[BNSpectrumRows];
    double windowEnergy;
    uint32_t index, lowIndex, filterIndex, filled, decimation, hop;
    uint64_t expectedFrame;
    bool hasClock;
};

double BNSpectrumRowFrequency(uint32_t row) {
    return BNSpectrumMinimumHz * pow((double)BNSpectrumMaximumHz/BNSpectrumMinimumHz,
                                    (double)row/(BNSpectrumRows-1));
}

static double responsePower(const BNSecondOrderCoefficients *c, double omega) {
    double cs = cos(omega), sn = sin(omega), c2 = cos(2*omega), s2 = sin(2*omega);
    double nr = c->b0+c->b1*cs+c->b2*c2, ni = c->b1*sn+c->b2*s2;
    double dr = 1+c->a1*cs+c->a2*c2, di = c->a1*sn+c->a2*s2;
    return (nr*nr+ni*ni)/(dr*dr+di*di);
}

void BNSpectrumReferenceWeights(double frequencyHz, double weights[3]) {
    double omega = 2*M_PI*fmax(0, fmin(BNSpectrumNyquistHz, frequencyHz))/BNSpectrumSampleRate;
    double rest = responsePower(&BNHighPass200, omega);
    weights[0] = responsePower(&BNLowPass200, omega);
    weights[1] = rest*responsePower(&BNLowPass2000, omega);
    weights[2] = rest*responsePower(&BNHighPass2000, omega);
    double sum = weights[0]+weights[1]+weights[2];
    for (int i = 0; i < 3; ++i) weights[i] /= sum;
}

BNSpectrum *BNSpectrumCreate(void) {
    BNSpectrum *s = calloc(1, sizeof(*s));
    if (!s) return NULL;
    s->fft = vDSP_create_fftsetup(15, kFFTRadix2);
    if (!s->fft) { free(s); return NULL; }
    for (int n = 0; n < BNSpectrumFFTSize; ++n) {
        double w = .5 - .5*cos(2*M_PI*n/BNSpectrumFFTSize);
        s->window[n] = w; s->windowEnergy += w*w;
    }
    double halfRow = pow((double)BNSpectrumMaximumHz/BNSpectrumMinimumHz, .5/(BNSpectrumRows-1));
    for (int row = 0; row < BNSpectrumRows; ++row) {
        s->frequency[row] = BNSpectrumRowFrequency(row);
        s->lower[row] = s->frequency[row]/halfRow;
        s->upper[row] = s->frequency[row]*halfRow;
    }
    return s;
}

void BNSpectrumDestroy(BNSpectrum *s) { if (s) { vDSP_destroy_fftsetup(s->fft); free(s); } }

void BNSpectrumReset(BNSpectrum *s) {
    s->index = s->lowIndex = s->filterIndex = s->filled = s->decimation = s->hop = 0;
    s->hasClock = false;
    memset(s->filterHistory, 0, sizeof(s->filterHistory));
    memset(s->power, 0, sizeof(s->power));
    memset(s->lowPower, 0, sizeof(s->lowPower));
}

static void spectrum(BNSpectrum *s, const float *samples, uint32_t stride,
                     uint32_t index, double rate, float *power) {
    memset(power, 0, (BNSpectrumFFTSize/2+1)*sizeof(float));
    // Stereo powers are averaged after transforming the ears separately.
    double scale = 1/(rate*s->windowEnergy);
    for (int ch = 0; ch < 2; ++ch) {
        for (int n = 0; n < BNSpectrumFFTSize; ++n)
            s->real[n] = samples[ch*stride+(index+n)%stride]*s->window[n];
        memset(s->imaginary, 0, sizeof(s->imaginary));
        DSPSplitComplex z = {s->real, s->imaginary};
        vDSP_fft_zip(s->fft, &z, 1, 15, FFT_FORWARD);
        for (int k = 0; k <= BNSpectrumFFTSize/2; ++k) {
            double p = (double)s->real[k]*s->real[k] + (double)s->imaginary[k]*s->imaginary[k];
            power[k] += p*scale*((k == 0 || k == BNSpectrumFFTSize/2) ? .5 : 1);
        }
    }
}

static double rowPower(const float *power, double rate, double loHz, double hiHz) {
    double lo = loHz*BNSpectrumFFTSize/rate;
    double hi = fmin(hiHz*BNSpectrumFFTSize/rate, BNSpectrumFFTSize/2.0);
    if (hi-lo < 1) {
        double center = fmin(sqrt(lo*hi), BNSpectrumFFTSize/2.0);
        int k = (int)center, next = k < BNSpectrumFFTSize/2 ? k+1 : k;
        return power[k]*(1-(center-k))+power[next]*(center-k);
    }
    double p = 0;
    for (int k = (int)floor(lo+.5); k <= (int)floor(hi+.5); ++k)
        p += power[k]*fmax(0, fmin(hi, k+.5)-fmax(lo, k-.5));
    return p/(hi-lo);
}

static void analyze(BNSpectrum *s, float *column) {
    // Delay the full-rate window by the FIR's group delay so both windows end
    // at the same source sample: 0.683 s above 80 Hz, 5.461 s below 40 Hz.
    spectrum(s, &s->samples[0][0], FullRingSize, s->index, BNSpectrumSampleRate, s->power);
    spectrum(s, &s->lowSamples[0][0], BNSpectrumFFTSize, s->lowIndex,
             (double)BNSpectrumSampleRate/BNSpectrumLowDecimation, s->lowPower);
    for (int row = 0; row < BNSpectrumRows; ++row) {
        double frequency = s->frequency[row];
        if (frequency > BNSpectrumNyquistHz) { column[row] = NAN; continue; }
        double p;
        if (frequency < 80) {
            p = rowPower(s->lowPower, (double)BNSpectrumSampleRate/BNSpectrumLowDecimation,
                         s->lower[row], s->upper[row]);
            if (frequency > 40) {
                double t = log2(frequency/40); t = t*t*(3-2*t);
                p = p*(1-t)+rowPower(s->power, BNSpectrumSampleRate, s->lower[row], s->upper[row])*t;
            }
        } else p = rowPower(s->power, BNSpectrumSampleRate, s->lower[row], s->upper[row]);
        column[row] = 10*log10(fmax(p, 1e-20));
    }
}

uint32_t BNSpectrumConsume(BNSpectrum *s, const BNCapturedFrame *frames, uint32_t count,
                          float *columns, uint64_t *endFrames, uint32_t capacity) {
    uint32_t produced = 0;
    for (uint32_t n = 0; n < count; ++n) {
        const BNCapturedFrame *f = &frames[n];
        if (s->hasClock && f->frame != s->expectedFrame) BNSpectrumReset(s);
        s->hasClock = true; s->expectedFrame = f->frame+1;
        float sample[2] = {f->left, f->right};
        for (int ch = 0; ch < 2; ++ch) {
            s->samples[ch][s->index] = sample[ch];
            s->filterHistory[ch][s->filterIndex] = sample[ch];
            s->filterHistory[ch][s->filterIndex+BNSpectrumFilterTaps] = sample[ch];
        }
        s->index = (s->index+1)%FullRingSize;
        s->filterIndex = (s->filterIndex+1)%BNSpectrumFilterTaps;
        if (s->filled < BNSpectrumWarmupFrames) ++s->filled;
        if (++s->decimation == BNSpectrumLowDecimation) {
            s->decimation = 0;
            if (s->filled >= BNSpectrumFilterTaps) {
                for (int ch = 0; ch < 2; ++ch)
                    vDSP_dotpr(s->filterHistory[ch]+s->filterIndex, 1, BNSpectrumDecimationFIR, 1,
                               &s->lowSamples[ch][s->lowIndex], BNSpectrumFilterTaps);
                s->lowIndex = (s->lowIndex+1)%BNSpectrumFFTSize;
            }
        }
        if (s->filled < BNSpectrumWarmupFrames) continue;
        if (s->hop == 0 && produced < capacity) {
            analyze(s, columns+produced*BNSpectrumRows);
            endFrames[produced++] = f->frame-BNSpectrumFilterDelay;
        }
        s->hop = (s->hop+1)%BNSpectrumHop;
    }
    return produced;
}

void BNSpectrumCopyPower(const BNSpectrum *s, float *density) { memcpy(density, s->power, sizeof(s->power)); }
void BNSpectrumCopyLowPower(const BNSpectrum *s, float *density) { memcpy(density, s->lowPower, sizeof(s->lowPower)); }
