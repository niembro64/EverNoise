// Long production-source test, streamed without keeping samples in memory.
#include "BrownNoiseDSP.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    int index = atoi(argv[1]);
    double hours = strtod(argv[2], NULL);
    if (index < 0 || index > 3 || !isfinite(hours) || hours <= 0) return 2;
    BNSourceKind kind = (BNSourceKind)index;
    double rate = BNRateForSource(kind);
    BNGenerator *g = BNCreateSource(kind, 123456789, true);
    if (!g) return 2;
    const double bounds[] = {.75, .020001, .109, .100001};
    float samples[4096];
    uint64_t total = (uint64_t)(hours * 3600 * rate), checked = 0;
    double peak = 0, sum = 0, squares = 0, minRMS = 1;
    uint64_t nextReport = (uint64_t)(rate * 3600 * 6);
    for (uint64_t offset = 0; offset < total; offset += 4096) {
        uint32_t count = total - offset < 4096 ? (uint32_t)(total - offset) : 4096;
        BNRenderMono(g, samples, count);
        double block = 0;
        for (uint32_t n = 0; n < count; ++n) {
            double x = samples[n];
            if (!isfinite(x) || fabs(x) > bounds[index]) return 1;
            if (offset > rate) {
                peak = fmax(peak, fabs(x)); sum += x; squares += x*x;
                block += x*x; checked++;
            }
        }
        if (offset > rate) {
            double rms = sqrt(block/count);
            minRMS = fmin(minRMS, rms);
            if (rms < .002) return 1;
        }
        if (offset >= nextReport) {
            printf("source=%d hours=%.0f\n", index, offset / (rate * 3600));
            fflush(stdout);
            nextReport += (uint64_t)(rate * 3600 * 6);
        }
    }
    printf("PASS source=%d hours=%.2f samples=%" PRIu64 " peak=%.9f rms=%.9f mean=%.9f minimum_block_rms=%.9f\n",index,hours,total,peak,sqrt(squares/checked),sum/checked,minRMS);
    BNDestroy(g);
    return 0;
}
