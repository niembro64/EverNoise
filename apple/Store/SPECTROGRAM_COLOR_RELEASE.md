# Full-range frequency colors — build 27

Build 27 expands Max's spectrogram to a logarithmic **2 Hz–48 kHz** axis and
assigns fixed frequency colors: muted rose for lows, sage for mids, and
periwinkle for highs. Actual final-output power controls brightness on a fixed
**−120 to −30 dBFS/Hz** scale. Changing the mix does not change the hue assigned
to a frequency. The sound engine, loudness adjustment, saved mix, peak protection,
audio driver and capture callback exactly match build 26.

**1.1 (27) is available in internal TestFlight for iOS and tvOS.** Apple
confirmed availability on November 16 at 20:29:43 CST and 20:31:44 CST,
respectively. Testing notes are saved for both platforms. Apple TV is also
Testing in Friends and Family, with automatic notification enabled. Apple
prevents another iOS version-1.1 external submission until build 25's beta
review is approved. The public App Store submissions were not changed. See
[delivery evidence](delivery-v27.json).

## Frequency bounds and color meaning

The existing source runs at 48 kHz, so the measurable source spectrum ends at
24 kHz. A dashed boundary and dim band explicitly mark 24–48 kHz as unmeasured;
these rows contain NaN, not invented samples or a claim of measured silence.
The axis gives room above the source's 18 kHz rolloff and below its 20 Hz
rolloff. Those filters have gradual tails, not sharp finite frequency bounds.
This update adds no new output frequencies.

For each row, the analyzer evaluates the **production crossover coefficients**
at equal input gains and normalizes the three squared-magnitude responses.
The shared pink shaping and outer rolloffs cancel in these relative weights.
Those weights blend the existing band colors in linear light. Neither current
slider/button settings nor instantaneous band fluctuations affect hue.

Measured stereo power spectral density controls lightness. Each row's color
is normalized to equal relative luminance before applying CIELAB L* from 0
to 70 over the fixed decibel range. This gives equal reference lightness to
equal measured power across red, green and blue, with all values inside the
sRGB gamut. The final RGB values use the exact sRGB transfer function. Silence
and unmeasured values are black; the UI independently shades the unmeasured
region. There is no per-frame or per-band automatic contrast adjustment.

## Resolving very low frequencies

The 32,768-point full-rate Hann analysis remains for frequencies above 80 Hz:
0.683 seconds per window, with 1.465 Hz FFT-bin spacing. A second analysis-only
path uses a 257-tap Kaiser low-pass FIR and 8× decimation to 6 kHz, followed by
another 32,768-point Hann FFT. That gives **0.1831 Hz bin spacing** and a
**5.461-second** window below 40 Hz. Between 40 and 80 Hz, a smooth logarithmic
blend combines the two **linear powers**, then converts to decibels. Bin spacing
is not the same as the Hann window's ability to resolve adjacent tones.

The FIR has less than 0.00002 dB error through 100 Hz and rejects frequencies
above the decimated Nyquist boundary by at least 123.9 dB in the coefficient
response. A tone that would otherwise alias into the 2 Hz region is suppressed
by more than 110 dB in the complete floating-point analysis test. Both FFTs
transform left and right separately and average powers, avoiding stereo phase
cancellation. The full-rate window is delayed by the FIR's 128-frame group delay
so both windows refer to the same source endpoint. Their averaging durations
still differ, so bass changes settle more slowly.

The first complete measurement takes **5.467 seconds** after enabling Max,
resuming or returning to the chart. A static “Measuring output…” message covers
this period. The observer still produces a column every 2,048 source frames
(23.4375 Hz), with about 22 seconds of history. Discontinuities reset both
windows instead of joining unrelated sample intervals.

All FIR, FFT, palette and image work runs in the existing visual worker. It
does not add audio latency or alter generated PCM. Disabled/hidden/paused
analysis, bounded capture, session leases, Reduce Motion and Off behavior are
unchanged. The observation point is after mix/offset/peak protection/fades and
before Apple's conversion, system volume and physical speakers.

## Validation

- **52 core tests**, **33 iOS integration tests**, and **10 tvOS integration
  tests** pass. The Off/Max/pause/continuous-audio UI flow passes on iPhone,
  iPad and Apple TV. Screenshots were inspected; the chart's header was moved
  clear of the settings gear on the phone/tablet layout.
- Independent NumPy/SciPy comparisons of production PCM match both FFT paths
  within **1.04e−7 relative PSD error**. Integrated PSD matches window-weighted
  time-domain power within **6.3e−11**. Log-row values agree within
  **0.000017 dB**, including the two-window blend.
- Equal-gain reference weights match the independent design SOS responses
  within **1.7e−13**. Palette tests cover equal lightness, monotonically increasing
  brightness, unchanged chromaticity, gamut, silence and unknown values.
- A minute of partitioned input produces exactly **1,406** subsequent columns
  at the correct frame times. Undefined-behavior and bounds sanitizers pass.
  The host Mac processes the analysis in **1.34 seconds**; this excludes image
  generation, device GPU work and physical-device battery measurements.
- Hashes confirm **17 audio DSP, playback, driver and capture files** are
  unchanged. Existing playback behavior and numerical peak-protection tests
  pass. Physical-device listening and overnight playback were not repeated
  for this visual update.

Detailed results are in [spectrogram-audit-v27.json](spectrogram-audit-v27.json).
Signed-package and source hashes are in
[build-27-manifest.json](build-27-manifest.json).

## Reproduce

Run `swift test` and the affected Xcode integration/UI tests. Run
`python3 scripts/design-spectrum-analysis.py` to verify the FIR design against
the checked-in coefficients. To independently validate measurements:

```sh
mkdir -p build/spectrum-color
clang -O2 -dynamiclib \
  -I Sources/BrownNoiseDSP/include -I Sources/SpectrumAnalysis/include \
  Sources/BrownNoiseDSP/BrownNoiseDSP.c Sources/BrownNoiseDSP/BNMixRenderer.c \
  Sources/SpectrumAnalysis/BNCapture.c Sources/SpectrumAnalysis/BNSpectrum.c \
  -framework Accelerate -o build/spectrum-color/libAudit.dylib
python3 scripts/check-spectrogram.py
```

Repeat the library build with `-fsanitize=undefined,bounds
-fno-sanitize-recover=all` to exercise the same independent audit with sanitizers.
The script accepts `--library` and `--report` filenames relative to
`build/spectrum-color`. Signed iOS and tvOS exports pass strict signature
verification, contain distribution entitlements and background audio, and
report version 1.1, build 27.
