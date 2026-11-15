// Exact production filters: linearity, worst-case headroom, and impulse export.
#include "../Sources/BrownNoiseDSP/BNComplementaryFilter.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    const int n = 192000;
    double *impulses[4];
    for (int band = 0; band < 4; ++band) {
        impulses[band] = calloc(n, sizeof(double));
        if (!impulses[band]) return 2;
        BNComplementaryFilter f = BNComplementaryCreate(band % 3);
        for (int i=0; i<n; ++i)
            impulses[band][i] = band == 3 ? BNComplementaryColor(&f, i == 0) * BNComplementaryGain
                                        : BNComplementaryProcess(&f, i == 0);
    }
    double worstSum = 0, maximumLinearityError = 0;
    for (int band=0; band<3; ++band) {
        BNComplementaryFilter adversary = BNComplementaryCreate(band);
        BNComplementaryFilter x = BNComplementaryCreate(band), y = x, sum = x;
        double peak = 0, l1 = 0, final = 0;
        for (int i=0; i<n; ++i) {
            double a = .45*sin(6.283185307179586*127*i/48000);
            double b = .45*cos(6.283185307179586*1999*i/48000);
            double separate = BNComplementaryProcess(&x,a) + BNComplementaryProcess(&y,b);
            double together = BNComplementaryProcess(&sum,a+b);
            maximumLinearityError = fmax(maximumLinearityError,fabs(separate-together));
            l1 += fabs(impulses[band][i]);
            // Reverse the impulse signs: a deliberately adversarial bounded
            // input that attains its finite L1 norm at the last sample.
            final = BNComplementaryProcess(&adversary,impulses[band][n-1-i] < 0 ? -1 : 1);
            peak = fmax(peak,fabs(final));
        }
        if (peak > BNComplementaryAbsoluteBounds[band]+1e-10 || fabs(final-l1)>1e-10) return 1;
        worstSum += final;
        printf("band=%d measured_L1=%.12f adversarial_peak=%.12f bound=%.12f\n",band,l1,peak,BNComplementaryAbsoluteBounds[band]);
    }
    if (maximumLinearityError>1e-10 || worstSum>.80000001) return 1;
    printf("PASS worst_sum=%.12f max_linearity_error=%.3g\n",worstSum,maximumLinearityError);
    FILE *out = fopen(argv[1],"wb"); if (!out) return 2;
    for (int band=0; band<4; ++band) {
        if (fwrite(impulses[band],sizeof(double),n,out)!=(size_t)n) return 2;
        free(impulses[band]);
    }
    return fclose(out) == 0 ? 0 : 2;
}
