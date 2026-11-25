#ifndef BN_PORTABLE_FFT_H
#define BN_PORTABLE_FFT_H
// Minimal radix-2 backend for the same analysis algorithm on Android and Wasm.
// Apple retains Accelerate. All tables and scratch storage are allocated at setup.
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
typedef struct { float *realp, *imagp; } DSPSplitComplex;
typedef struct BNFFTPlan { uint32_t size, *reverse; float *cosine, *sine; } *FFTSetup;
enum { kFFTRadix2 = 2, FFT_FORWARD = -1 };
static FFTSetup vDSP_create_fftsetup(uint32_t bits, int radix) {
    (void)radix;
    FFTSetup p = calloc(1, sizeof(*p));
    if (!p) return NULL;
    p->size = 1u << bits;
    p->reverse = calloc(p->size, sizeof(uint32_t));
    p->cosine = calloc(p->size / 2, sizeof(float));
    p->sine = calloc(p->size / 2, sizeof(float));
    if (!p->reverse || !p->cosine || !p->sine) {
        free(p->reverse); free(p->cosine); free(p->sine); free(p); return NULL;
    }
    for (uint32_t i = 0; i < p->size; ++i) {
        uint32_t x = i, rev = 0;
        for (uint32_t b = 0; b < bits; ++b) { rev = (rev << 1) | (x & 1); x >>= 1; }
        p->reverse[i] = rev;
    }
    for (uint32_t i = 0; i < p->size / 2; ++i) {
        double a = -2 * M_PI * i / p->size;
        p->cosine[i] = (float)cos(a); p->sine[i] = (float)sin(a);
    }
    return p;
}
static void vDSP_destroy_fftsetup(FFTSetup p) {
    free(p->reverse); free(p->cosine); free(p->sine); free(p);
}
static void vDSP_fft_zip(FFTSetup p, DSPSplitComplex *z, int stride, uint32_t bits, int direction) {
    (void)stride; (void)bits; (void)direction;
    float *re = z->realp, *im = z->imagp;
    for (uint32_t i = 0; i < p->size; ++i) {
        uint32_t j = p->reverse[i];
        if (j > i) { float x = re[i]; re[i] = re[j]; re[j] = x; x = im[i]; im[i] = im[j]; im[j] = x; }
    }
    for (uint32_t size = 2; size <= p->size; size <<= 1) {
        uint32_t half = size / 2, step = p->size / size;
        for (uint32_t start = 0; start < p->size; start += size) {
            for (uint32_t j = 0; j < half; ++j) {
                uint32_t a = start + j, b = a + half, k = j * step;
                float r = re[b] * p->cosine[k] - im[b] * p->sine[k];
                float i = re[b] * p->sine[k] + im[b] * p->cosine[k];
                re[b] = re[a] - r; im[b] = im[a] - i; re[a] += r; im[a] += i;
            }
        }
    }
}
static void vDSP_dotpr(const float *a, int as, const float *b, int bs, float *out, uint32_t count) {
    float sum = 0;
    for (uint32_t n = 0; n < count; ++n) sum += a[n * as] * b[n * bs];
    *out = sum;
}
#endif
