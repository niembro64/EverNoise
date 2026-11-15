// Accelerated endurance test of the same callback renderer used by the app.
#include "BrownNoiseDSP.h"
#include <inttypes.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

int main(int argc, char **argv) {
    const double sampleRate = BNSourceSampleRate();
    enum { blockSize = 1024 };
    const int writeSample = argc == 3 && strcmp(argv[1], "--sample") == 0;
    double hours = argc == 2 ? strtod(argv[1], NULL) : 30;
    if (hours <= 0 || !isfinite(hours)) return 2;
    const uint64_t total = writeSample ? (uint64_t)(sampleRate * 64) : (uint64_t)(sampleRate * 3600 * hours);
    FILE *sampleFile = writeSample ? fopen(argv[2], "wb") : NULL;
    if (writeSample && !sampleFile) return 2;
    BNGenerator *generator = BNCreate(sampleRate, 123456789);
    if (!generator) return 2;
    float samples[blockSize];
    AudioBufferList buffers = {.mNumberBuffers = 1, .mBuffers = {{1, sizeof(samples), samples}}};
    double sum = 0, squares = 0, peak = 0, maxStep = 0, maxBoundaryStep = 0;
    double minBlockRMS = 1, maxBlockRMS = 0;
    float previous = 0;
    uint64_t checked = 0, blocks = 0;
    time_t started = time(NULL);
    uint64_t nextReport = (uint64_t)(sampleRate * 3600 * 6);
    for (uint64_t offset = 0; offset < total; offset += blockSize) {
        uint32_t count = total - offset < blockSize ? (uint32_t)(total - offset) : blockSize;
        BNRenderAudioBuffers(generator, &buffers, count);
        double blockSquares = 0;
        for (uint32_t i = 0; i < count; ++i) {
            double value = samples[i];
            if (!isfinite(value) || fabs(value) > 0.75) {
                fprintf(stderr, "Invalid sample at %" PRIu64 "\n", offset + i);
                return 1;
            }
            if (offset > sampleRate) {
                double step = fabs(value - previous);
                if (step > maxStep) maxStep = step;
                if (i == 0 && step > maxBoundaryStep) maxBoundaryStep = step;
                sum += value;
                squares += value * value;
                blockSquares += value * value;
                if (fabs(value) > peak) peak = fabs(value);
                checked++;
            }
            previous = samples[i];
        }
        if (offset > sampleRate) {
            double rms = sqrt(blockSquares / count);
            if (rms < minBlockRMS) minBlockRMS = rms;
            if (rms > maxBlockRMS) maxBlockRMS = rms;
            if (rms < 0.002 || rms > 0.3) {
                fprintf(stderr, "Silent or unstable block at %" PRIu64 ": %f\n", offset, rms);
                return 1;
            }
        }
        if (sampleFile && fwrite(samples, sizeof(float), count, sampleFile) != count) return 2;
        blocks++;
        if (!writeSample && offset >= nextReport) {
            printf("Rendered %.0f hours of audio; elapsed %ld seconds\n", offset / (sampleRate * 3600), (long)(time(NULL) - started));
            fflush(stdout);
            nextReport += (uint64_t)(sampleRate * 3600 * 6);
        }
    }
    if (sampleFile) fclose(sampleFile);
    BNDestroy(generator);
    double rms = sqrt(squares / checked);
    double mean = sum / checked;
    int passed = fabs(mean) < 0.001 && rms > 0.035 && rms < 0.055 && maxBoundaryStep < 0.08;
    printf("%s: %" PRIu64 " samples, %" PRIu64 " blocks, %.2f audio hours, %ld wall seconds\n", passed ? "PASS" : "FAIL", total, blocks, total / (sampleRate * 3600), (long)(time(NULL) - started));
    printf("mean=%.8f rms=%.6f peak=%.6f block_rms=[%.6f,%.6f] max_step=%.6f boundary_step=%.6f\n", mean, rms, peak, minBlockRMS, maxBlockRMS, maxStep, maxBoundaryStep);
    return passed ? 0 : 1;
}
