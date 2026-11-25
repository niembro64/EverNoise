// Stream the production stereo path beyond 32-bit frame counts without files.
#include "BrownNoiseDSP.h"
#include "../Sources/BrownNoiseDSP/BNComplementaryCoefficients.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <time.h>

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    int index = atoi(argv[1]);
    double hours = strtod(argv[2], NULL);
    if (index < 0 || index > 6 || !isfinite(hours) || hours <= 0) return 2;
    BNSourceKind kind = (BNSourceKind)index;
    double rate = BNRateForSource(kind);
    BNStereoGenerator *g = BNStereoCreateSource(kind, 123456789, 987654321, true);
    if (!g) return 2;
    BNStereoSetLevel(g, 4); BNStereoBeginFadeIn(g);
    const double bounds[] = {.75, .020001, .109, .100001,
        BNComplementaryAbsoluteBounds[0], BNComplementaryAbsoluteBounds[1], BNComplementaryAbsoluteBounds[2]};
    float left[4096], right[4096];
    uint64_t total = (uint64_t)(hours * 3600 * rate), checked = 0;
    double peak[2] = {0}, squares[2] = {0}, sum[2] = {0}, minRMS[2] = {1, 1};
    uint64_t interval = (uint64_t)(rate * 37), nextChange = interval, changes = 0;
    uint64_t nextReport = (uint64_t)(rate * 3600 * 6);
    clock_t start = clock();
    for (uint64_t offset = 0; offset < total; offset += 4096) {
        if (offset >= nextChange) {
            BNStereoSetEnabled(g, changes % 2 != 0);
            ++changes; nextChange = offset + interval;
        }
        uint32_t count = total - offset < 4096 ? (uint32_t)(total - offset) : 4096;
        BNStereoRender(g, left, right, count);
        double block[2] = {0};
        for (uint32_t n = 0; n < count; ++n) {
            double values[2] = {left[n], right[n]};
            for (int c = 0; c < 2; ++c) {
                double x = values[c];
                if (!isfinite(x) || fabs(x) > bounds[index]) return 1;
                if (offset > rate) {
                    peak[c] = fmax(peak[c], fabs(x)); sum[c] += x;
                    squares[c] += x*x; block[c] += x*x;
                }
            }
            if (offset > rate) checked++;
        }
        if (offset > rate) {
            for (int c = 0; c < 2; ++c) {
                double rms = sqrt(block[c]/count);
                minRMS[c] = fmin(minRMS[c], rms);
                if (rms < .001) return 1;
            }
        }
        if (offset >= nextReport) {
            printf("source=%d hours=%.0f frames=%" PRIu64 "\n", index, offset / (rate * 3600), BNStereoRenderedFrames(g));
            fflush(stdout); nextReport += (uint64_t)(rate * 3600 * 6);
        }
    }
    if (BNStereoRenderedFrames(g) != total) return 1;
    printf("PASS source=%d hours=%.1f frames=%" PRIu64 " switches=%" PRIu64 " CPU_seconds=%.3f\n",index,hours,total,changes,(double)(clock()-start)/CLOCKS_PER_SEC);
    for (int c=0;c<2;++c) printf("channel=%d peak=%.9f rms=%.9f mean=%.9f minimum_block_rms=%.9f\n", c,peak[c],sqrt(squares[c]/checked),sum[c]/checked,minRMS[c]);
    BNStereoDestroy(g); return 0;
}
