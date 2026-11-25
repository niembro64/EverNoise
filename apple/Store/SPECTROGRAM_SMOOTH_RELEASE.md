# Max spectrum smoothing — 1.1 (29)

Build 29 makes the measured-output spectrogram smoother in frequency, time,
and brightness. Settings renames **Volume offset** to **App Loudness** on
both iOS and tvOS; its saved preference key, range, and behavior stay intact.
All extra spectrum work is exclusive to visible, sounding Max mode.

## Measurement and brightness

The old chart already converted power to decibels. Its shortcomings were a
single transition between two windows whose lengths differed by 8x, a change
between bin interpolation and integration, limited image precision, and a
brightness scale expressed per hertz on a logarithmic frequency axis.

The new chart measures energy per octave. For a PSD S(f), the log-frequency
energy density is S(f) × f × ln(2). Overlapping Gaussian kernels average this
quantity in log frequency, then seven resolutions blend in **linear power**.
Consequently ideal pink noise is level across octaves and white noise rises
by approximately 3.01 dB/octave. This is a change of measurement units, not EQ
or a change to the sound being generated.

Brightness uses a fixed, loudness-inspired contrast proxy, doubling per 10 dB,
with a smooth shoulder and CIELAB lightness conversion. Equal octave energy
receives equal relative luminance across the muted frequency hues. There is
no automatic exposure, no adult hearing weighting, and no hard bright-end
clipping. The reference is −35 dBFS/octave and the display floor −100.

This is **not** a calibrated acoustic loudness or sound-pressure meter. True
loudness depends on level, frequency, and listening conditions. The common
10 dB doubling approximation is not universal; see the [NASA loudness study](https://ntrs.nasa.gov/api/citations/20240006900/downloads/QD_24_Time_Integration_v3.pdf?attachment=true).
The app measures before hardware volume and speaker processing. Fixed hues
still come from the production crossover responses at equal input gains.

## Continuous resolution and presentation

- 1024 logarithmic rows, 2 Hz–48 kHz. Above the source's 24 kHz Nyquist limit
  remains unmeasured, black, and shaded separately.
- Seven Hann windows: 5.461, 2.731, 1.365, 0.683, 0.341, 0.171, and 0.085 s.
  Their log-duration weights overlap smoothly around a 96-cycle target.
- Three longest windows use the existing 8x, 257-tap anti-alias decimator.
  All endpoints compensate its 128-source-sample group delay.
- 4x zero padding samples each window's continuous spectrum more densely;
  it does **not** create additional physical resolving power.
- Gaussian frequency smoothing has a nominal 1/12-octave FWHM, gradually
  widening at the very bottom to respect the finite low-frequency resolution.
- 800-sample hops produce 60 measured columns per second. Even the shortest
  window overlaps 80.47%; longer windows overlap more.
- Three symmetric 80 ms temporal filters smooth linear power before dB/color
  conversion. Longer bass windows still respond more slowly; simultaneous
  endpoints do not imply identical time resolution at all frequencies.
- A 16-bit-per-component linear-sRGB image preserves gradients through the
  intermediate color conversion and interpolation. The final display's own
  bit depth remains device-dependent.
- 22 s of history plus 32 guard columns and a 0.4 s presentation buffer absorb
  uneven image delivery. Geometry follows sample timestamps rather than
  restarting an animation on each image. A genuine stall holds measured data;
  the app does not invent future sound. Image batches need not arrive at the
  same rate as the 60 Hz spectrum columns or the display timeline.
- Reduce Motion presents once per second while still draining the capture
  queue frequently, avoiding repeated warmups caused by sleeping the consumer.

All FFTs, weighting, color conversion, and image copying run on the analysis
actor. The real-time producer remains the same bounded, nonblocking SPSC
capture path. If graphics cannot keep up, visual data may drop; the audio
callback never waits for it. Max intentionally costs more processing. Off,
Low, Med, and High retain their existing behavior.

## Validation

[Independent numerical audit](spectrogram-audit-v29.json): actual production
PCM, separate double-precision NumPy/SciPy FFTs and quadrature, Parseval,
stereo powers, gain scaling, time smoothing, arbitrary callback partitions,
and synthetic pink-noise flatness all passed. Maximum visible row error was
0.000031 dB; measured 20 Hz–18 kHz pink-noise deviation was at most 0.185 dB.
Analytical white-noise octave-energy error was under 0.002 dB. A 65.47 s run
produced 3601 columns in 19.80 s on this M1 Max, including Python transfer but
excluding Swift images/GPU. This is a host measurement, not a phone battery
or thermal guarantee.

[Audio identity](audio-unchanged-v29.json): all DSP, gain/limiter, playback,
and capture-producer source hashes match build 28. 1,024,000 samples per
channel compare bit-for-bit across all 125 mixes, −18/0/+3 dB offsets, and
Mono/Stereo changes. Build 28's true-peak and 30-hour sound qualifications
remain documented in [the sound release record](FAMILY_SPECTRUM_RELEASE.md);
those measurements were not rerun or relabeled as new build 29 listening tests.

Core tests cover calibration, near-2 Hz resolution and alias rejection,
exact silence, capture isolation, and sample-clock resets. Integration checks
cover equal-luminance hues, monotonic brightness, high-precision gradients,
renderable native 16-bit images, continuous presentation geometry, and the
live audio engine under simultaneous analysis/image generation. iPhone,
iPad, and TV load checks kept the engine running with zero dropped visual
samples. These Debug simulator runs are not physical-device performance tests.

Initial test-only assumptions were corrected: a one-dB RGB gradient does not
need 800 distinct values out of 1000 samples (it still provides over 50x the
old 8-bit precision), and one image can contain several analysis columns.
The load gate checks source-clock progress, bounded lag, and dropped samples
instead of equating snapshot count with spectrum frequency.

The final matrix includes 52 core tests, 38 iOS integration tests, 17 tvOS
integration tests, and the affected iPhone/iPad/TV UI flows. AddressSanitizer
could not start on this host: sampling showed its initializer recursively
waiting in a dyld/malloc spinlock before main. That attempt was terminated;
it is not reported as a pass. Undefined-behavior/bounds instrumentation and
explicit output canaries are recorded separately with the release manifest.
Signed package hashes and distribution status are recorded with that manifest
and the delivery record.
