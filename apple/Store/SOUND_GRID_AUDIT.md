# Sound grid — build 5

Version 1.0 (5), November 13, 2026. Replaces the three presets with 25 balances:
five high-frequency levels horizontally, five midrange levels vertically, and
the approved Brown bass bed at constant gain everywhere.

## Behavior and presentation

Highs increase left to right; mids increase bottom to top. Both axes range from
0 to 4. The cell color has fixed sRGB red 0.70, green `0.07 + 0.16*mids`, and blue
`0.07 + 0.16*highs`. Each cell has at least a 44-point touch target. The selected
cell has a border/checkmark; VoiceOver announces both levels and selection.
The mapping is a visual analogy, not a physical conversion of light to sound.

The app saves both coordinates. Upgrading preserves Brown at (0,0) and Gray
at (4,0); the former White choice maps to the brightest balance (4,4), now with
the required bass bed. Changing the grid while paused stays paused. Opening the
app still starts playback; no timer or network dependency is introduced.

## DSP

- Brown remains the identical 8 kHz generator/filter/gain. The grid never sends
  it a new level. There is no whole-mix normalization that would turn down bass
  when mids/highs increase.
- Highs use the unchanged 48 kHz Gray air source from build 4.
- Mids add independent 48 kHz noise with four 600 Hz high-pass stages followed
  by four 3 kHz low-pass stages. The smooth band edges naturally overlap adjacent
  frequencies. This is a linear filter, with no waveshaper, clipping, compressor,
  or AGC.
- Mid gain is calculated once at creation from the absolute impulse-response
  sum plus a conservative infinite-tail bound. It bounds every source sample
  below 0.10 for excitation in [-1,1]. The eight filter states retain continuity.
- All three layers keep running in one AVAudioEngine graph. Atomic integer
  targets select amplitudes 0, 0.25, 0.5, 0.75, or 1. Gain changes use the existing
  600 ms smoothstep from the current gain, including rapid reversals. No graph
  teardown, source restart, buffer allocation, locks, or I/O occur on selection.
- Source bounds at maximum overlap: Brown <=0.75, mids <0.10, highs <0.109;
  the combined bound is below 0.959 before conversion. Actual converted output
  was measured separately because resampling can overshoot sample peaks.

Existing startup/pause/resume and audio-session recovery behavior is retained.
See [the original audio audit](AUDIO_AUDIT.md) for OS interruption boundaries.

## Verification

**29 core tests, five real-engine integration tests, and the UI test passed.**
The tests cover all five layer gains, first-sample continuity after changing a
fractional target, gain clamping, callback partition invariance, saved zero
coordinates, migration/persistence, all 25 cells, axis direction, touch sizes,
selected accessibility state, pause intent, engine identity/start count, and
background render-clock continuity. The final result is
`build/noise-grid-v5/IntegrationAndUI.xcresult`.

**All 25 grid positions were rendered through Apple's actual mixer at 48 kHz**
for 30 seconds each. Nine further 120-second cases cover four corners at 44.1 kHz,
rapid switching at 44.1/48 kHz, slower switching, 16 kHz mono, and 48 kHz mono.

- Every render had finite samples, identical stereo channels, no silent buffers,
  and no render retries. The rapid 48 kHz case made 3,214 selection changes.
- Maximum estimated 8x intersample peak across all renders: **0.221314
  (-13.10 dBFS)**. No clipping occurred in these measurements.
- Measured 20–200 Hz bass power differed by only **0.000011 dB** across all 25
  cells. The bass generator itself is exactly unchanged; the tiny difference
  is residual contribution from the smooth band filters.
- Every upward step increased measured 1–3 kHz power; every rightward step
  increased 8–12 kHz power. These checks ran across all rows and columns.
- (0,0) exactly matches the earlier approved Brown engine output, including
  startup, at 44.1 and 48 kHz. (4,0) exactly matches build 4's Gray at 48 kHz.
- A 128-frame callback can coincide with a natural waveform trough even in the
  unchanged Brown signal. Silence checks use the actual samples and independently
  measure 100 ms RMS windows; every tested window remained above 0.015.

The new midrange production source passed **48 accelerated hours**:
8,294,400,000 samples, peak 0.056299, RMS 0.009611, near-zero mean, and minimum
4096-sample block RMS 0.008006. Every sample was finite and bounded; no silent
blocks after startup. Brown/high layers retain the previously audited filters;
this run did not repeat their earlier 48-hour tests.

[Measurements](grid-measurements.json) · [Spectrum](grid-spectrum.png) ·
[Source/package hashes](build-5-manifest.json)

These are deterministic software and simulator checks. Physical-device listening
to the grid, an actual overnight run, battery, Bluetooth, and all OS interruption
combinations remain unverified. The user's smooth-sound confirmation applies to
the preserved Brown sound, not yet to every new balance.

## Reproduction

```sh
swift test
xcodebuild -project JustBrownNoise.xcodeproj -scheme JustBrownNoise \
  -destination 'platform=iOS Simulator,id=5B047664-25F8-4885-BAD1-009F2171692F' test
cc -std=c11 -O3 -I Sources/BrownNoiseDSP/include \
  -c Sources/BrownNoiseDSP/BrownNoiseDSP.c -o build/noise-grid-v5/dsp.o
swiftc -O -import-objc-header Sources/BrownNoiseDSP/include/BrownNoiseDSP.h \
  scripts/render-grid.swift build/noise-grid-v5/dsp.o -o build/noise-grid-v5/render-grid
build/noise-grid-v5/render-grid 48000 30 4,4 build/noise-grid-v5/grid-48000-4-4.wav
uv run --with numpy --with scipy --with matplotlib python scripts/check-grid.py
cc -std=c11 -O3 -I Sources/BrownNoiseDSP/include \
  Sources/BrownNoiseDSP/BrownNoiseDSP.c scripts/source-endurance.c \
  -o build/noise-grid-v5/source-endurance
build/noise-grid-v5/source-endurance 3 48
```

The analysis expects all 34 render cases under `build/noise-grid-v5/` and the
previous Brown/Gray reference WAVs. The example above illustrates one cell.
