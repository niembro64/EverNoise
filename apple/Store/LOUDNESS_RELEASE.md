# Mix loudness and saved offset — build 25

The user approved relative Low/Mid/High mixing, a stable remembered listening
level, very slow leveling, and separate peak protection. This changes output
level substantially; it retains the build-23 filters and spectral balance.
The complete prior app is tagged **sound-baseline-build-24** at `b4b62d9`.
The original favorite remains tagged **sound-baseline-build-22**. Legacy DSP
APIs remain available for repeatable comparisons.

**1.1 (25) is available in TestFlight on iOS and tvOS.** Apple confirmed internal
availability on November 16 at 18:15:57 CST and 18:16:58 CST, respectively.
Testing notes are saved on both platforms. iOS external testing is Waiting for
Review; tvOS is Testing in Personal Testing and Friends and Family. Automatic
notification is enabled. Public App Store submissions were not changed: iOS
1.0.1 (23) remains Ready for Distribution and tvOS 1.1 (24) remains Waiting for
Review at this turn's live check. See [delivery evidence](delivery-v25.json).

## Behavior and design

- Low/Mid/High keep Off / -18 / -12 / -6 / 0 dB **relative weights**. Common
  scaling cancels during normalization. All-off remains exact silence.
- A saved **Volume offset** in Settings adjusts the nominal -20 LUFS stereo
  target from -18 to +3 dB, in 1 dB steps. Default is 0 dB. It never writes
  device volume or raises the peak-protection ceiling. The UI uses a native
  slider on iPhone/iPad/Mac/Vision Pro and a native picker on Apple TV.
- Calibration uses the expected K-weighted power of each unchanged filter
  driven by its bounded, independent random excitation. `design-loudness.py`
  generates constants from the saved complementary design. K weighting and
  the stereo power sum follow [ITU-R BS.1770-5 Annex 1](https://www.itu.int/rec/R-REC-BS.1770-5-202311-I).
  This is stationary-noise leveling, not a certified gated programme meter.
- Mix transitions interpolate normalized power coordinates over 600 ms and
  renormalize the intermediate vector, avoiding a change in expected loudness.
  Stereo transitions use a normalized one-second blend without the old
  right-channel power dip. Neither operation resets filters, random state,
  the audio session, or the engine.
- Residual power is measured with a 30-second time constant. A common gain
  corrects with the **same 60-second time constant in both directions**, bounded
  to +/-1 dB. Measurement is before the offset, peak protection, and output
  fades; correction freezes during silence/fades. It cannot fight a limiter
  or amplify silence. Manual offset changes ease over three seconds.
- One C renderer owns six continuous band generators and the stereo output.
  Complete mix commands are atomic. The callback has no allocation, locks,
  file/network access, or buffer-length-dependent state. Startup remains
  750 ms, resume 250 ms, and pause 80 ms. Play/pause fades follow the delayed
  signal so pause does not wait for lookahead to drain.

## Peak protection

Protection is separate from slow loudness correction. A 129-tap, four-phase
reconstruction estimates intersample peaks; exact detector-aligned sample
peaks are included. Both channels share gain. A rolling minimum spans the
complete support of two 50 ms moving averages. Every gain contribution is at
most the demand for the delayed sample, allowing a smooth predictive ramp
without waiting for an overload to appear at the output. Release is 10 seconds.
Total audio delay is 4,814 frames (100.29 ms) at 48 kHz.

The internal sample ceiling is **-3 dBFS**. Independent 16x reconstruction and
Apple conversion checks must stay below **-2 dBTP**, retaining conversion
margin. The detector is not itself a proof for every possible DAC or external
processing chain. There is no hard clipping, saturation, or waveshaper. A
limiter can still modulate audio when engaged; tests must report engagement,
not describe nonlinear protection as mathematically distortion-free.

## Validation

Detailed evidence: [loudness-audit-v25.json](loudness-audit-v25.json).

- All 125 mixes at both 0 and +3 dB offsets: maximum measured loudness error
  **0.072 LU** in ten-second renders, excluding the first second from loudness
  measurement. Independent 16x reconstruction includes the complete signal.
- Maximum reconstructed peak across these cases and the longer examples:
  **0.658067 full scale**. The default 60-second example measures -19.994 LUFS,
  approximately 0.0754 RMS per channel (about 25.1 dB above the old default).
- Separate overload tests use bass, high-frequency sinusoids, +/- steps,
  alternating samples, and impulses up to 100 full scale. Reconstructed output
  stays below 0.707938. Below threshold, peak protection is exactly a delay:
  maximum sine passthrough residual is zero.
- **36 actual AVAudioEngine renders** cover 8–192 kHz, one/two output channels,
  Mono/Stereo, and rapid mix/mode/offset changes. Largest reconstructed peak:
  **0.611636**. These are software conversion measurements, not recordings
  from a physical speaker.
- **45 core tests pass**, including sample-exact callback partitioning,
  proportional-mix invariance, offset ratios, silent/paused gain freeze,
  pause/resume, clamping, and rapid changes. All 40 prior core tests still pass.
- iOS integration and the new saved-offset UI flow pass. The first UI attempt
  used a simulator's old all-off preference; its fixture now sets an audible
  mix explicitly. The prior attempt and corrected result are retained locally.
- **30 accelerated hours** pass: 5,184,000,000 frames per channel, 1,265,625
  buffers, and 3,476 mix changes. No nonfinite samples, clipping, or silent
  buffers occurred. Maximum sample peak was 0.707938, minimum protection gain
  0.903837, and slow correction stayed between 0.995724 and 1.004561. This
  crosses the 32-bit frame boundary. Runtime was 1,201.675 CPU seconds.
- Apple TV's nine integration tests and both remote UI flows pass, including
  offset selection and uninterrupted background clock advancement. iOS's
  29 integration tests, existing stereo UI flow, and corrected offset UI flow
  pass. The offset control was visually verified on iOS. tvOS screenshot
  captures inconsistently omit the native Settings sheet; remote selection and
  the saved value are verified, but a final physical-TV visual check remains.
- Undefined-behavior and array-bounds sanitizer runs pass for the overload
  harness and a 72-second renderer stress run. AddressSanitizer could not run:
  Apple's runtime deadlocked in shadow-memory initialization before `main`.
  The captured process sample is retained; no AddressSanitizer pass is claimed.
- Both iOS and tvOS signed App Store packages verify strictly, with background
  audio, distribution entitlements, correct version/build, and source/package
  hashes recorded in [build-25-manifest.json](build-25-manifest.json).

Physical-device listening and overnight hardware playback remain unverified.
These checks do not establish identical perceived loudness on different
speakers or guarantee a match to every video.

## Reproduce

`python3 scripts/design-loudness.py` verifies generated coefficients. Compile
`BNMixRenderer.c` as `build/libNoiseLoudness.dylib`, compile and run
`scripts/peak-protection-audit.c`, then run `scripts/check-loudness.py`.
`scripts/render-loudness.swift` uses the same production renderer through
AVAudioEngine; `scripts/check-loudness-conversion.py` checks those recordings.
`scripts/loudness-endurance.c` takes an accelerated-hour count and report path.
Run `swift test`, plus the iOS and tvOS Xcode test schemes for app integration.

Disk cleanup during qualification removed regenerable compilation caches and
203 old generated WAVs from builds 5–7 whose numerical sidecar reports remain.
Source baselines, release archives, measurement reports, and the build-25
examples remain intact.
