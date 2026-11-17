#include "BNPeakProtector.h"
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    BNPeakProtector *p = calloc(1, sizeof(*p)); if (!p) return 3;
    BNPeakReset(p);
    // Before any overload, this stage must be a pure delay, not a waveshaper.
    double passthroughError = 0;
    for (int n = 0; n < 96000; ++n) {
        double left, right, x = .2*sin(2*M_PI*997*n/48000);
        BNPeakProcess(p, x, x, &left, &right);
        double expected = n < BNPeakDelay ? 0 : .2*sin(2*M_PI*997*(n-BNPeakDelay)/48000);
        passthroughError = fmax(passthroughError, fabs(left-expected));
        if (left != right) return 4;
    }
    if (passthroughError > 1e-12) return 5;
    BNPeakReset(p);
    FILE *f = fopen(argv[1], "wb"); if (!f) return 6;
    double peak = 0, minGain = 1, maxGainStep = 0, previousGain = 1;
    for (int n = 0; n < 48000*20; ++n) {
        double time = n/48000.0, x, y;
        if (time < 1) x = .2*sin(2*M_PI*997*time);
        else if (time < 3) x = 8*sin(2*M_PI*40*time);
        else if (time < 5) x = 4*sin(2*M_PI*19789*time+.4);
        else if (time < 7) x = (n%701 == 0) ? 100 : 0;
        else if (time < 9) x = (n&1) ? -2 : 2;
        else if (time < 11) x = (n%6000 < 3000) ? 3 : -3;
        else x = .2*sin(2*M_PI*997*time);
        y = .7*x + .1*sin(2*M_PI*12007*time);
        double left, right; BNPeakProcess(p, x, y, &left, &right);
        if (!isfinite(left) || !isfinite(right)) return 7;
        peak = fmax(peak, fmax(fabs(left), fabs(right)));
        minGain = fmin(minGain, p->gain);
        maxGainStep = fmax(maxGainStep, fabs(p->gain-previousGain)); previousGain = p->gain;
        float samples[2] = {(float)left, (float)right}; fwrite(samples, sizeof(float), 2, f);
    }
    fclose(f); free(p);
    printf("{\"passthroughError\":%.12g,\"peak\":%.12g,\"minimumGain\":%.12g,\"maximumGainStep\":%.12g}\n",
           passthroughError, peak, minGain, maxGainStep);
    return peak < .707947 && maxGainStep < 1.0/2400 + 1e-10 ? 0 : 8;
}
