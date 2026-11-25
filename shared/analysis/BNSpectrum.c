#include "SpectrumAnalysis.h"
#include "BNSpectrumDecimation.h"
// Use the generator's immutable coefficients for stable reference colors.
#include "../dsp/BNComplementaryCoefficients.h"
#if defined(__APPLE__) && !defined(BN_FORCE_PORTABLE_ANALYSIS)
#include <Accelerate/Accelerate.h>
#else
#include "BNPortableFFT.h"
#endif
#include <math.h>
#include <stdlib.h>
#include <string.h>

enum { FullRingSize = BNSpectrumFFTSize + BNSpectrumFilterDelay,
       StageCount = 7, Padding = 4, MaximumFFT = BNSpectrumFFTSize * Padding };
typedef struct {
    uint32_t first, count;
    float *weights;
    double mix;
} FrequencyKernel;
typedef struct {
    FFTSetup fft;
    uint32_t size, fftSize, log2FFT;
    bool lowRate;
    double rate, windowEnergy;
    float *window, *power;
    FrequencyKernel rows[BNSpectrumRows];
} SpectrumStage;
struct BNSpectrum {
    SpectrumStage stages[StageCount];
    float samples[2][FullRingSize], lowSamples[2][BNSpectrumFFTSize];
    float filterHistory[2][2*BNSpectrumFilterTaps];
    float real[MaximumFFT], imaginary[MaximumFFT];
    double frequency[BNSpectrumRows], smoothed[3][BNSpectrumRows];
    uint32_t index, lowIndex, filterIndex, filled, decimation, hop;
    uint64_t expectedFrame;
    bool hasClock, hasSmoothed;
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

static bool makeKernel(FrequencyKernel *kernel, const SpectrumStage *stage, double hz) {
    // Overlapping Gaussian kernels avoid the old one-bin interpolation boundary.
    // A 0.12 Hz minimum width acknowledges finite resolution at the axis bottom.
    double sigma = hypot((1.0/12)/2.354820045, .12/(hz*M_LN2));
    double binHz = stage->rate/stage->fftSize;
    kernel->first = (uint32_t)fmax(1, ceil(hz*exp2(-6*sigma)/binHz));
    uint32_t last = (uint32_t)fmin(stage->fftSize/2, floor(hz*exp2(6*sigma)/binHz));
    if (last < kernel->first) { kernel->mix = 0; return true; }
    kernel->count = last-kernel->first+1;
    kernel->weights = calloc(kernel->count, sizeof(float));
    if (!kernel->weights) return false;
    double normalization = 0;
    for (uint32_t n = 0; n < kernel->count; ++n) {
        uint32_t k = kernel->first+n;
        double frequency = k*binHz, distance = log2(frequency/hz)/sigma;
        double weight = exp(-.5*distance*distance);
        kernel->weights[n] = weight;
        // Change variables from Hz to octaves. Averaging S(f)*f*ln(2) in
        // log-frequency gives energy per octave; a 1/f PSD stays level.
        // PSD already carries the half-weight Nyquist endpoint.
        normalization += weight*binHz/(frequency*M_LN2)*(k == stage->fftSize/2 ? .5 : 1);
    }
    for (uint32_t n = 0; n < kernel->count; ++n)
        kernel->weights[n] *= binHz/normalization;
    return true;
}

BNSpectrum *BNSpectrumCreate(void) {
    BNSpectrum *s = calloc(1, sizeof(*s));
    if (!s) return NULL;
    const uint32_t sizes[StageCount] = {32768, 16384, 8192, 32768, 16384, 8192, 4096};
    for (int i = 0; i < StageCount; ++i) {
        SpectrumStage *stage = &s->stages[i];
        stage->size = sizes[i]; stage->fftSize = sizes[i]*Padding;
        stage->log2FFT = (uint32_t)log2(stage->fftSize);
        stage->lowRate = i < 3;
        stage->rate = stage->lowRate ? (double)BNSpectrumSampleRate/BNSpectrumLowDecimation : BNSpectrumSampleRate;
        stage->fft = vDSP_create_fftsetup(stage->log2FFT, kFFTRadix2);
        stage->window = calloc(stage->size, sizeof(float));
        stage->power = calloc(stage->fftSize/2+1, sizeof(float));
        if (!stage->fft || !stage->window || !stage->power) { BNSpectrumDestroy(s); return NULL; }
        for (uint32_t n = 0; n < stage->size; ++n) {
            double w = .5-.5*cos(2*M_PI*n/stage->size);
            stage->window[n] = w; stage->windowEnergy += w*w;
        }
    }
    for (int row = 0; row < BNSpectrumRows; ++row) {
        double hz = s->frequency[row] = BNSpectrumRowFrequency(row);
        if (hz > BNSpectrumNyquistHz) continue;
        double distance[StageCount], nearest = INFINITY;
        for (int i = 0; i < StageCount; ++i) {
            SpectrumStage *stage = &s->stages[i];
            // Target 96 cycles per window, with broad overlapping weights in
            // log duration. No fixed frequency switches or 8x window jump.
            double d = log2((stage->size/stage->rate)/(96/hz))/.65;
            distance[i] = d*d; nearest = fmin(nearest, distance[i]);
        }
        double total = 0;
        for (int i = 0; i < StageCount; ++i) {
            SpectrumStage *stage = &s->stages[i];
            FrequencyKernel *kernel = &stage->rows[row];
            kernel->mix = exp(-.5*(distance[i]-nearest));
            if (kernel->mix < 1e-8) { kernel->mix = 0; continue; }
            if (!makeKernel(kernel, stage, hz)) { BNSpectrumDestroy(s); return NULL; }
            total += kernel->mix;
        }
        for (int i = 0; i < StageCount; ++i) s->stages[i].rows[row].mix /= total;
    }
    return s;
}

void BNSpectrumDestroy(BNSpectrum *s) {
    if (!s) return;
    for (int i = 0; i < StageCount; ++i) {
        SpectrumStage *stage = &s->stages[i];
        if (stage->fft) vDSP_destroy_fftsetup(stage->fft);
        free(stage->window); free(stage->power);
        for (int row = 0; row < BNSpectrumRows; ++row) free(stage->rows[row].weights);
    }
    free(s);
}

void BNSpectrumReset(BNSpectrum *s) {
    s->index = s->lowIndex = s->filterIndex = s->filled = s->decimation = s->hop = 0;
    s->hasClock = s->hasSmoothed = false;
    memset(s->filterHistory, 0, sizeof(s->filterHistory));
    memset(s->smoothed, 0, sizeof(s->smoothed));
    for (int i = 0; i < StageCount; ++i)
        memset(s->stages[i].power, 0, (s->stages[i].fftSize/2+1)*sizeof(float));
}

static void spectrum(BNSpectrum *s, SpectrumStage *stage) {
    uint32_t stride = stage->lowRate ? BNSpectrumFFTSize : FullRingSize;
    uint32_t index = ((stage->lowRate ? s->lowIndex : s->index)+BNSpectrumFFTSize-stage->size)%stride;
    const float *samples = stage->lowRate ? &s->lowSamples[0][0] : &s->samples[0][0];
    memset(stage->power, 0, (stage->fftSize/2+1)*sizeof(float));
    double scale = 1/(stage->rate*stage->windowEnergy);
    // Average stereo powers, never samples: opposite-phase ears must not
    // cancel. Zero padding samples the Hann-window spectrum more densely.
#if !defined(__APPLE__) || defined(BN_FORCE_PORTABLE_ANALYSIS)
    // Pack real left and right into one complex FFT. For real signals,
    // |L(k)|^2 + |R(k)|^2 = (|Z(k)|^2 + |Z(N-k)|^2) / 2.
    // This preserves stereo power (including opposite-phase channels) while
    // halving FFT work on platforms without Accelerate.
    for (uint32_t n = 0; n < stage->size; ++n) {
        uint32_t at = (index+n)%stride;
        s->real[n] = samples[at]*stage->window[n];
        s->imaginary[n] = samples[stride+at]*stage->window[n];
    }
    memset(s->real+stage->size, 0, (stage->fftSize-stage->size)*sizeof(float));
    memset(s->imaginary+stage->size, 0, (stage->fftSize-stage->size)*sizeof(float));
    DSPSplitComplex z = {s->real, s->imaginary};
    vDSP_fft_zip(stage->fft, &z, 1, stage->log2FFT, FFT_FORWARD);
    for (uint32_t k = 0; k <= stage->fftSize/2; ++k) {
        uint32_t mirror = (stage->fftSize-k)%stage->fftSize;
        double p = (double)s->real[k]*s->real[k]+(double)s->imaginary[k]*s->imaginary[k];
        double q = (double)s->real[mirror]*s->real[mirror]+(double)s->imaginary[mirror]*s->imaginary[mirror];
        stage->power[k] = (p+q)*.5*scale*((k == 0 || k == stage->fftSize/2) ? .5 : 1);
    }
#else
    for (int ch = 0; ch < 2; ++ch) {
        for (uint32_t n = 0; n < stage->size; ++n)
            s->real[n] = samples[ch*stride+(index+n)%stride]*stage->window[n];
        memset(s->real+stage->size, 0, (stage->fftSize-stage->size)*sizeof(float));
        memset(s->imaginary, 0, stage->fftSize*sizeof(float));
        DSPSplitComplex z = {s->real, s->imaginary};
        vDSP_fft_zip(stage->fft, &z, 1, stage->log2FFT, FFT_FORWARD);
        for (uint32_t k = 0; k <= stage->fftSize/2; ++k) {
            double p = (double)s->real[k]*s->real[k]+(double)s->imaginary[k]*s->imaginary[k];
            stage->power[k] += p*scale*((k == 0 || k == stage->fftSize/2) ? .5 : 1);
        }
    }
#endif
}

static void analyze(BNSpectrum *s, float *column) {
    // All seven windows end at the same FIR-delay-compensated source sample.
    for (int i = 0; i < StageCount; ++i) spectrum(s, &s->stages[i]);
    double alpha = -expm1(-(double)BNSpectrumHop/BNSpectrumSampleRate/.08);
    for (int row = 0; row < BNSpectrumRows; ++row) {
        if (s->frequency[row] > BNSpectrumNyquistHz) { column[row] = NAN; continue; }
        double p = 0;
        for (int i = 0; i < StageCount; ++i) {
            SpectrumStage *stage = &s->stages[i];
            FrequencyKernel *kernel = &stage->rows[row];
            if (kernel->mix == 0) continue;
            float value;
            vDSP_dotpr(stage->power+kernel->first, 1, kernel->weights, 1, &value, kernel->count);
            p += value*kernel->mix;
        }
        // Three gentle, symmetric low-pass stages smooth changes in slope as
        // well as brightness. Smooth power, not dB or separately encoded RGB.
        for (int i = 0; i < 3; ++i) {
            if (!s->hasSmoothed) s->smoothed[i][row] = p;
            else s->smoothed[i][row] += alpha*(p-s->smoothed[i][row]);
            p = s->smoothed[i][row];
        }
        column[row] = 10*log10(fmax(p, 1e-20));
    }
    s->hasSmoothed = true;
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

void BNSpectrumCopyPower(const BNSpectrum *s, float *density) {
    for (int k = 0; k <= BNSpectrumFFTSize/2; ++k) density[k] = s->stages[3].power[k*Padding];
}
void BNSpectrumCopyLowPower(const BNSpectrum *s, float *density) {
    for (int k = 0; k <= BNSpectrumFFTSize/2; ++k) density[k] = s->stages[0].power[k*Padding];
}
