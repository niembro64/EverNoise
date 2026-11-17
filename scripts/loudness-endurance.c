// Production renderer continuity/headroom audit. Arguments: hours report.json
#include "BrownNoiseDSP.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    double hours = atof(argv[1]);
    uint64_t total = (uint64_t)(hours * 3600 * 48000), done = 0, blocks = 0;
    BNMixGenerator *g = BNMixCreate(8237098127346ULL);
    if (!g) return 3;
    float left[4096], right[4096];
    double peak = 0, sum = 0, previous[2] = {0}, boundary = 0;
    double minimumGain = 1, minSlow = 1, maxSlow = 1, minRMS = 1;
    int changes = 0;
    uint64_t nextChange = 48000 * 31ULL;
    clock_t start = clock();
    while (done < total) {
        if (done >= nextChange) {
            // Include prolonged bass-only at the highest offset, independent
            // stereo and mono, all active mix ratios, and slow offset changes.
            int cell = (changes * 37) % 124 + 1;
            BNMixSetLevels(g, cell/25, (cell/5)%5, cell%5);
            BNMixSetOffsetDB(g, changes%3 == 0 ? 3 : 0);
            BNMixSetStereo(g, changes%2 == 0);
            ++changes; nextChange = done + 48000 * 31ULL;
        }
        uint32_t n = (uint32_t)(total-done > 4096 ? 4096 : total-done);
        BNMixRender(g, left, right, n);
        double blockPower = 0;
        for (uint32_t i = 0; i < n; ++i) {
            double samples[2] = {left[i], right[i]};
            for (int ch = 0; ch < 2; ++ch) {
                double x = samples[ch];
                if (!isfinite(x) || fabs(x) > .707947) {
                    fprintf(stderr, "FAIL invalid/over-ceiling frame=%llu\n", (unsigned long long)(done+i)); return 4;
                }
                peak = fmax(peak, fabs(x)); blockPower += x*x;
                if (done > 48000 && i == 0) boundary = fmax(boundary, fabs(x-previous[ch]));
                previous[ch] = x;
            }
        }
        if (done > 48000) {
            double rms = sqrt(blockPower/(2*n));
            if (rms < 1e-5) { fprintf(stderr, "FAIL silent buffer\n"); return 5; }
            minRMS = fmin(minRMS, rms);
        }
        BNMixMetrics m = BNMixReadMetrics(g);
        minimumGain = fmin(minimumGain, m.protectionGain);
        minSlow = fmin(minSlow, m.slowGain); maxSlow = fmax(maxSlow, m.slowGain);
        sum += blockPower; done += n; ++blocks;
    }
    if (BNMixRenderedFrames(g) != total) return 6;
    FILE *f = fopen(argv[2], "w"); if (!f) return 7;
    fprintf(f, "{\"hours\":%.6f,\"framesPerChannel\":%llu,\"buffers\":%llu,\"mixChanges\":%d,"
        "\"peak\":%.12g,\"RMS\":%.12g,\"maximumBoundaryStep\":%.12g,\"minimumBlockRMS\":%.12g,"
        "\"minimumProtectionGain\":%.12g,\"minimumSlowGain\":%.12g,\"maximumSlowGain\":%.12g,\"cpuSeconds\":%.3f}\n",
        hours, (unsigned long long)done, (unsigned long long)blocks, changes, peak, sqrt(sum/(2*done)),
        boundary, minRMS, minimumGain, minSlow, maxSlow, (double)(clock()-start)/CLOCKS_PER_SEC);
    fclose(f); BNMixDestroy(g);
    printf("PASS %.2f accelerated hours, peak %.9f\n", hours, peak);
    return 0;
}
