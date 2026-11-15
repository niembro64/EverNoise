// Exercise the exact production filter with adversarial inputs and pure tones.
#include "../Sources/BrownNoiseDSP/BNColorFilter.h"
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    const double rates[] = {8000, 44100, 48000, 96000, 384000};
    for (unsigned r = 0; r < sizeof(rates) / sizeof(rates[0]); ++r) {
        double rate = rates[r];
        BNColorFilter a = BNColorCreate(rate), b = a, combined = a, impulse = a;
        double peak = 0, error = 0, l1 = 0;
        for (int n = 0; n < (int)(rate * 2); ++n) {
            double x = .45 * sin(6.283185307179586 * 123 * n / rate);
            double y = .45 * cos(6.283185307179586 * 997 * n / rate);
            double u = BNColorProcess(&a, x), v = BNColorProcess(&b, y);
            double w = BNColorProcess(&combined, x + y);
            error = fmax(error, fabs(w - (u + v)));
            l1 += fabs(BNColorProcess(&impulse, n == 0 ? 1 : 0));
        }
        BNColorFilter stress = BNColorCreate(rate);
        for (int n = 0; n < (int)(rate * 4); ++n) {
            // Full-scale steps, alternation, and bounded deterministic excitation.
            double x = n < rate ? 1 : n < rate * 2 ? -1 : (n % 2 ? 1 : -1);
            peak = fmax(peak, fabs(BNColorProcess(&stress, x)));
        }
        printf("rate=%.0f linearity_error=%.3g impulse_L1=%.9f adversarial_peak=%.6f\n", rate, error, l1, peak);
        if (error > 1e-12 || l1 > .75 || peak > .75) return 1;
    }
    const int rate = 8000, length = 8000;
    const double tau = 6.28318530717958647693;
    double thdMax = 0;
    for (int frequency = 100; frequency <= 1000; frequency += 900) {
        BNColorFilter tone = BNColorCreate(rate);
        double re[32] = {0}, im[32] = {0};
        int harmonics = (rate / 2 - 1) / frequency;
        if (harmonics > 31) harmonics = 31;
        for (int n = 0; n < rate * 2; ++n) {
            double value = BNColorProcess(&tone, .95 * sin(tau * frequency * n / rate));
            if (n < rate) continue;
            for (int h = 1; h <= harmonics; ++h) {
                double phase = tau * frequency * h * (n - rate) / length;
                re[h] += value * cos(phase); im[h] -= value * sin(phase);
            }
        }
        double fundamental = hypot(re[1], im[1]);
        double distortion = 0;
        for (int h = 2; h <= harmonics; ++h) distortion += re[h]*re[h] + im[h]*im[h];
        double thd = sqrt(distortion) / fundamental;
        thdMax = fmax(thdMax, thd);
        printf("tone=%dHz amplitude=.95 THD=%.9g%%\n", frequency, thd * 100);
    }
    return thdMax < 1e-8 ? 0 : 1;
}
