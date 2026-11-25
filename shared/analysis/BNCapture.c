#include "SpectrumAnalysis.h"
#include <stdatomic.h>
#include <stdlib.h>

_Static_assert(ATOMIC_BOOL_LOCK_FREE == 2 && ATOMIC_LLONG_LOCK_FREE == 2,
               "Audio capture must be lock free");
struct BNCapture {
    _Atomic(bool) enabled;
    _Atomic(uint64_t) written, read, dropped;
    uint64_t clock; // producer only; advances even when capture is disabled
    BNCapturedFrame samples[BNCaptureCapacity];
};
BNCapture *BNCaptureCreate(void) {
    BNCapture *c = calloc(1, sizeof(*c));
    if (c) {
        atomic_init(&c->enabled, false); atomic_init(&c->written, 0);
        atomic_init(&c->read, 0); atomic_init(&c->dropped, 0);
    }
    return c;
}
void BNCaptureDestroy(BNCapture *c) { free(c); }
void BNCaptureSetEnabled(BNCapture *c, bool enabled) {
    atomic_store_explicit(&c->enabled, enabled, memory_order_relaxed);
}
static uint32_t available(BNCapture *c, uint32_t frames, uint64_t *write) {
    *write = atomic_load_explicit(&c->written, memory_order_relaxed);
    uint64_t read = atomic_load_explicit(&c->read, memory_order_acquire);
    uint64_t room = BNCaptureCapacity - (*write - read);
    return frames < room ? frames : (uint32_t)room;
}
static void finish(BNCapture *c, uint64_t write, uint32_t copied, uint32_t frames) {
    atomic_store_explicit(&c->written, write + copied, memory_order_release);
    if (copied < frames) atomic_fetch_add_explicit(&c->dropped, frames - copied, memory_order_relaxed);
    c->clock += frames;
}
void BNCapturePlanar(BNCapture *c, const float *left, const float *right, uint32_t frames) {
    if (!atomic_load_explicit(&c->enabled, memory_order_relaxed)) { c->clock += frames; return; }
    uint64_t write; uint32_t count = available(c, frames, &write);
    for (uint32_t n = 0; n < count; ++n)
        c->samples[(write+n) % BNCaptureCapacity] = (BNCapturedFrame){left[n], right[n], c->clock+n};
    finish(c, write, count, frames);
}
#if defined(__APPLE__)
void BNCaptureAudioBuffers(BNCapture *c, const AudioBufferList *buffers, uint32_t frames) {
    if (!atomic_load_explicit(&c->enabled, memory_order_relaxed)) { c->clock += frames; return; }
    uint64_t write; uint32_t count = available(c, frames, &write);
    for (uint32_t n = 0; n < count; ++n) {
        float sample[2] = {0, 0}; unsigned channel = 0;
        for (unsigned b = 0; b < buffers->mNumberBuffers && channel < 2; ++b) {
            const AudioBuffer *buffer = &buffers->mBuffers[b];
            const float *data = buffer->mData;
            for (unsigned ch = 0; ch < buffer->mNumberChannels && channel < 2; ++ch, ++channel)
                if (data) sample[channel] = data[n*buffer->mNumberChannels+ch];
        }
        if (channel == 1) sample[1] = sample[0];
        c->samples[(write+n) % BNCaptureCapacity] = (BNCapturedFrame){sample[0], sample[1], c->clock+n};
    }
    finish(c, write, count, frames);
}
#endif
uint32_t BNCaptureRead(BNCapture *c, BNCapturedFrame *out, uint32_t capacity) {
    uint64_t read = atomic_load_explicit(&c->read, memory_order_relaxed);
    uint64_t count = atomic_load_explicit(&c->written, memory_order_acquire) - read;
    if (count > capacity) count = capacity;
    for (uint32_t n = 0; n < count; ++n) out[n] = c->samples[(read+n) % BNCaptureCapacity];
    atomic_store_explicit(&c->read, read+count, memory_order_release);
    return (uint32_t)count;
}
void BNCaptureDiscard(BNCapture *c) {
    atomic_store_explicit(&c->read, atomic_load_explicit(&c->written, memory_order_acquire), memory_order_release);
}
uint64_t BNCapturePublishedFrames(const BNCapture *c) { return atomic_load_explicit(&c->written, memory_order_relaxed); }
uint64_t BNCaptureDroppedFrames(const BNCapture *c) { return atomic_load_explicit(&c->dropped, memory_order_relaxed); }
