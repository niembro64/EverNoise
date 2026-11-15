# White, Brown, and warm Gray — build 4

Version 1.0 (4), November 13, 2026. The user confirmed that the revised Brown
sound is smooth and consistent on the iPhone speaker. Build 4 preserves that
sound and adds two choices. Physical-device listening to White/Gray and an
actual overnight run of this build remain unverified.

## What Gray means here

Gray noise is noise shaped to compensate for frequency-dependent hearing
sensitivity. Equal-loudness contours vary with sound level; the listener and
speaker response also matter. The app's Gray is a deliberately warm,
hearing-shaped approximation: the approved bass-rich Brown signal plus a gentle
high-frequency layer, with less energy around the sensitive midrange. It is not
a calibrated inverse ISO 226 curve or an individualized equal-loudness signal.

Sources: [myNoise's gray-noise explanation](https://mynoise.net/NoiseMachines/greyNoiseGenerator.php)
and [ISO 226:2023](https://www.iso.org/standard/83117.html). ISO describes
pure-tone equal-loudness contours, not a unique broadband-noise recipe.

## Signal and continuity

- Brown retains its 8 kHz source, filter coefficients, fixed gain, and PRNG.
  Raw production samples match the prior implementation exactly. The actual
  Apple-engine output also matches the previous audit's entire 120-second Brown
  renders exactly at both 44.1 and 48 kHz, including the startup fade.
- White is independent uniform random noise at 48 kHz with fixed gain 0.02.
  Its power spectral density is flat through the audible range before output
  conversion. Constant gain is intentional; there is no compressor or limiter.
- Gray keeps Brown at its original gain. Its independent air source runs at
  48 kHz through two 5 kHz high-pass and two 10 kHz low-pass stages, gain 0.10.
  All filters are stable and linear, with no clipping, peak shaping, or AGC.
- All three streams remain in one audio graph. Selection changes only atomic
  gain targets, using 600 ms smoothstep fades from the current gains. Filter
  and random states continue even when a layer is inaudible. Rapid reversals
  begin at the existing gain. Changing a selection does not start a paused app.
- Selection is saved locally in UserDefaults. Brown is the first-launch default.
  Existing startup, pause/resume, interruption, route and media-reset behavior
  is retained. See [the earlier audio audit](AUDIO_AUDIT.md) for lifecycle limits.

For bounded input, the Brown source bound is 0.75 and White is 0.02. The air
source bound is `0.10 * (2 * exp(-2*pi*5000/48000))^2 < 0.109` (each high-pass
has that L1 norm; each low-pass has norm 1). Even full overlap of all three is
less than 0.879 before sample-rate conversion. Conversion can overshoot, so
actual mixer output and estimated intersample peaks were checked separately.
These analytic bounds are conservative, not the measured normal signal level.

## Measured results

All tests passed:

- 25 Swift core tests, including callback partition invariance, selection fades,
  rapid reversal continuity, restart selection, and exact Brown preservation.
- Five real-engine integration tests. Mode changes preserve engine identity,
  engine start count, and the advancing sample clock; paused selection remains
  paused. Existing restart/pause/fade checks still pass.
- One simulator UI flow covers launch, pause/resume, background continuity,
  all three selections, paused selection, and persistence across relaunch.
- 48 accelerated hours for each production source separately. Every sample
  remained finite and bounded; no silent 4096-sample blocks after startup.

| Source | Samples | Peak | RMS |
| --- | ---: | ---: | ---: |
| Brown | 1,382,400,000 | 0.250591 | 0.044376 |
| White | 8,294,400,000 | 0.020000 | 0.011547 |
| Gray air layer | 8,294,400,000 | 0.037025 | 0.010544 |

Twelve 120-second renders use Apple's actual AVAudioEngine mixer and converters:
Brown, White, Gray, 7-second switching, and rapid 37 ms selection changes at
44.1/48 kHz, plus Gray at 16 kHz and 48 kHz mono. All passed finite-sample,
channel agreement, DC, silent-block, and headroom checks. There were no manual
render retries. Across these renders the largest estimated 8x intersample peak
was **0.215898, or -13.32 dBFS**. The rapid 48 kHz run made **3,214** changes.
White's maximum sample step is naturally larger than Brown's; a large adjacent
sample difference alone is not evidence of a click in broadband noise.

The 48 kHz Gray spectrum has more bass, a dip near 3 kHz, and a gentle treble
return. The plot and detailed metrics are [here](noise-options-spectrum.png)
and [here](noise-options-measurements.json). The equal-loudness claim is limited
to approximate spectral intent; no calibrated acoustic listening test was done.

Accelerated source tests do not establish 48-hour real-time iPhone playback,
battery consumption, Bluetooth reliability, or freedom from OS interruptions.
The combined Apple graph was rendered for two minutes per case; its lifecycle
was exercised by simulator integration/UI tests. Real speaker confirmation for
this build remains the next listening check.

## Artifacts and reproduction

`Store/build-4-manifest.json` hashes the production sources and signed IPA.
Logs, renders, baseline samples, and `IntegrationAndUI.xcresult` are under
`build/noise-options/`. Source manifests identify the exact implementation.

```sh
swift test
xcodebuild -project JustBrownNoise.xcodeproj -scheme JustBrownNoise \
  -destination 'platform=iOS Simulator,id=5B047664-25F8-4885-BAD1-009F2171692F' test
cc -std=c11 -O3 -I Sources/BrownNoiseDSP/include \
  Sources/BrownNoiseDSP/BrownNoiseDSP.c scripts/source-endurance.c \
  -o build/noise-options/source-endurance
build/noise-options/source-endurance 0 48
build/noise-options/source-endurance 1 48
build/noise-options/source-endurance 2 48
cc -std=c11 -O3 -I Sources/BrownNoiseDSP/include \
  -c Sources/BrownNoiseDSP/BrownNoiseDSP.c -o build/noise-options/dsp.o
swiftc -O -import-objc-header Sources/BrownNoiseDSP/include/BrownNoiseDSP.h \
  scripts/render-options.swift build/noise-options/dsp.o \
  -o build/noise-options/render-options
build/noise-options/render-options 48000 120 gray build/noise-options/gray-48000.wav
uv run --with numpy --with scipy --with matplotlib python scripts/check-options.py
```

The analysis script expects the complete render set and earlier Brown reference
WAVs; the single render command above illustrates one case. Use `brown`, `white`,
`gray`, `switch`, and `rapid` at 44100 and 48000, plus Gray at 16000 and the optional
final channel argument `1` for the mono case.
