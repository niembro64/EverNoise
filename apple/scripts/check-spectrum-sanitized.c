// Compile with -fsanitize=undefined,bounds (and address where supported).
// Exercises the analysis consumer,
// never a device audio route. Complements the independent numerical oracle.
#include "SpectrumAnalysis.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    BNCapturedFrame *frames = calloc(4096, sizeof(*frames));
    float *storage = calloc(6*BNSpectrumRows+2, sizeof(float));
    assert(frames && storage);
    unsigned columns = 0;
    for (int pass = 0; pass < 4; ++pass) {
        BNSpectrum *s = BNSpectrumCreate(); assert(s);
        uint64_t ends[6];
        for (int block = 0; block < 140; ++block) {
            for (int n = 0; n < 4096; ++n) {
                uint64_t frame = (uint64_t)block*4096+n;
                float x = pass == 0 ? 0 : .1*sin(2*M_PI*(pass == 1 ? 2 : 1000)*frame/48000);
                frames[n] = (BNCapturedFrame){x, -x, frame+(pass == 3 && block >= 70 ? 1000 : 0)};
            }
            storage[0] = storage[6*BNSpectrumRows+1] = 12345;
            uint32_t count = BNSpectrumConsume(s, frames, 4096, storage+1, ends, 6);
            assert(count <= 6 && storage[0] == 12345 && storage[6*BNSpectrumRows+1] == 12345);
            for (uint32_t c = 0; c < count; ++c) {
                for (int row = 0; row < BNSpectrumRows; ++row) {
                    float value = storage[1+c*BNSpectrumRows+row];
                    assert(BNSpectrumRowFrequency(row) <= 24000 ? isfinite(value) : isnan(value));
                    if (pass == 0 && BNSpectrumRowFrequency(row) <= 24000) assert(value == -200);
                }
            }
            columns += count;
        }
        BNSpectrumReset(s);
        BNSpectrumDestroy(s);
    }
    free(frames); free(storage);
    printf("{\"passed\":true,\"frames\":%u,\"columns\":%u,\"checks\":\"undefined behavior, bounds, buffer canaries, silence, phase-inverted stereo, clock discontinuity\"}\n", 4*140*4096, columns);
}
