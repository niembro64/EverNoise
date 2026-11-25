// Exercise the six-level production command path with UBSan and bounds checks.
#include "BrownNoiseDSP.h"
#include <assert.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>

int main(void) {
    BNMixGenerator *g = BNMixCreate(57480231);
    assert(g);
    float left[4098], right[4098];
    uint64_t total = 0;
    for (int command = 0; command < 2160; ++command) {
        int mix = command % 216;
        BNMixSetLevels(g, mix / 36, (mix / 6) % 6, mix % 6);
        BNMixSetOffsetDB(g, command % 2 ? 3 : -18);
        BNMixSetStereo(g, command % 3 == 0);
        if (command % 217 == 0) BNMixSetLevels(g, INT_MIN, INT_MAX, 7);
        if (command % 251 == 0) BNMixSetPlaying(g, false);
        else BNMixSetPlaying(g, true);
        unsigned count = 1 + (command * 37) % 4096;
        left[0] = right[0] = left[count+1] = right[count+1] = 123456;
        BNMixRender(g, left+1, right+1, count);
        assert(left[0] == 123456 && right[0] == 123456);
        assert(left[count+1] == 123456 && right[count+1] == 123456);
        for (unsigned i = 1; i <= count; ++i) {
            assert(isfinite(left[i]) && isfinite(right[i]));
            assert(fabs(left[i]) < .707948 && fabs(right[i]) < .707948);
        }
        total += count;
    }
    BNMixSetLevels(g, 0, 0, 0);
    for (int block = 0; block < 24; ++block) {
        BNMixRender(g, left, right, 4096); total += 4096;
        if (block > 12) for (int i = 0; i < 4096; ++i)
            assert(left[i] == 0 && right[i] == 0);
    }
    assert(BNMixRenderedFrames(g) == total);
    BNMixDestroy(g);
    printf("{\"passed\":true,\"commands\":2160,\"framesPerChannel\":%llu,\"guardCanariesIntact\":true,\"allOffExactSilence\":true}\n", (unsigned long long)total);
    return 0;
}
