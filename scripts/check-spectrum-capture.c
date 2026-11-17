// Concurrent SPSC stress test, including disabled capture and a stalled reader.
#include "SpectrumAnalysis.h"
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

typedef struct { BNCapture *capture; _Atomic(bool) done, failed; uint64_t checked; } Audit;
static void *produce(void *context) {
    Audit *a = context;
    float left[256], right[256];
    for (uint64_t block = 0; block < 100000; ++block) {
        BNCaptureSetEnabled(a->capture, block%37 != 0);
        for (unsigned n = 0; n < 256; ++n) {
            left[n] = (float)((block*256+n)%4096)/4096;
            right[n] = -left[n];
        }
        BNCapturePlanar(a->capture, left, right, 256);
        if (block%8 == 0) usleep(100);
    }
    atomic_store(&a->done, true);
    return NULL;
}
static void *consume(void *context) {
    Audit *a = context;
    BNCapturedFrame samples[4096];
    uint64_t previous = 0; bool first = true;
    usleep(50000); // Deliberately fill the queue before the consumer starts.
    for (;;) {
        unsigned count = BNCaptureRead(a->capture, samples, 4096);
        for (unsigned n = 0; n < count; ++n) {
            float expected = (float)(samples[n].frame%4096)/4096;
            if (samples[n].left != expected || samples[n].right != -expected ||
                (!first && samples[n].frame <= previous)) atomic_store(&a->failed, true);
            previous = samples[n].frame; first = false; ++a->checked;
        }
        if (count == 0 && atomic_load(&a->done)) break;
        if (a->checked%32768 < 4096) usleep(1000);
    }
    return NULL;
}
int main(void) {
    Audit a = {.capture = BNCaptureCreate()};
    if (!a.capture) return 2;
    atomic_init(&a.done, false); atomic_init(&a.failed, false);
    pthread_t producer, consumer;
    if (pthread_create(&consumer, NULL, consume, &a) || pthread_create(&producer, NULL, produce, &a)) return 3;
    pthread_join(producer, NULL); pthread_join(consumer, NULL);
    uint64_t published = BNCapturePublishedFrames(a.capture), dropped = BNCaptureDroppedFrames(a.capture);
    bool passed = !atomic_load(&a.failed) && a.checked == published && dropped > 0;
    printf("{\"passed\":%s,\"sourceFrames\":25600000,\"checkedFrames\":%llu,\"droppedVisualFrames\":%llu}\n",
           passed ? "true" : "false", (unsigned long long)a.checked, (unsigned long long)dropped);
    BNCaptureDestroy(a.capture);
    return passed ? 0 : 1;
}
