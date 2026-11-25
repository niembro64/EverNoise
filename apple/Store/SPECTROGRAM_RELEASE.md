# Off and output spectrogram — build 26

Build 26 adds Off and Max to the existing Low / Med / High animation control.
Med remains the default; saved preferences keep their meaning. The audio DSP,
mix normalization, saved Volume offset and peak protection are unchanged from
build 25. Source hashes and numerical results are in
[spectrogram-audit-v26.json](spectrogram-audit-v26.json).

**1.1 (26) is available in internal TestFlight for iOS and tvOS.** Apple
confirmed availability on November 16 at 19:05:19 CST and 19:08:10 CST,
respectively. Notes are saved for both platforms. TV is Testing in Personal
Testing and Friends and Family, with automatic notification enabled. Apple
prevents adding iOS build 26 to external groups until build 25's first
version-1.1 beta review is approved. The iOS build is not queued for external
review. Public App Store submissions were not changed. See
[delivery evidence](delivery-v26.json).

## Appearance and performance

- **Off** removes the infinity and ribbons entirely. It instantiates no artwork
  TimelineView or shader and schedules no spectrum capture, analysis or image
  updates. User controls still work and audio keeps running.
- **Low** retains the still infinity; **Med** animates the infinity; **High**
  includes the floating background ribbons.
- **Max** replaces the infinity with the output spectrogram, retaining the
  background ribbons. Frequency is logarithmic from 20 Hz at the bottom to
  20 kHz at the top. Time runs left to right across approximately 22 seconds.
  Color represents power spectral density on a fixed −100 to −30 dBFS/Hz
  scale; there is no visual automatic gain adjustment.
- Pause or all bands Off freezes the spectrogram and makes it grayscale.
  Analysis also stops while the app is backgrounded or Settings covers it.
  Reduce Motion uses one history update per second without interpolated motion.
  Changes to Reduce Motion restart the display task at the new cadence.
- The phone chart clears the gear's touch target. TV labels are larger for
  viewing distance. VoiceOver identifies the chart and its axes; it does not
  announce every measurement.

## Measurement and audio isolation

The observer copies the final generated stereo PCM after mix normalization,
Volume offset, peak protection, lookahead and playback fades. It measures
48 kHz digital output before Apple's route conversion, system volume or
physical speaker response. It does not record the microphone.

The source callback writes to a preallocated, lock-free, single-producer /
single-consumer ring. Disabled capture performs one atomic enabled check and
advances its sample clock per callback. There are no FFTs, image allocations,
locks, waits, networking, or graph changes on the audio thread. A stalled
visual consumer loses visual samples; it cannot delay the sound. Source sample
timestamps identify gaps and reset the analysis window rather than joining
unrelated sample intervals.

A persistent serial Swift actor owns the analysis and image work. The
32,768-point periodic Hann window uses Apple's Accelerate complex FFT with
a 2,048-frame hop: approximately 23.44 measurements per second and 1.465 Hz
bin spacing. Each channel is transformed separately and their **powers** are
averaged, preserving energy even for opposite-phase stereo. One-sided PSD is
normalized by sample rate and window energy. Broad logarithmic rows integrate
fractional FFT-bin contributions; rows narrower than one bin interpolate.
The display has 512 frequency rows and approximately 22 seconds of history.

The immutable image is built off the audio and main threads. An extra history
column permits continuous subpixel motion without changing the measured
values. The palette progresses from black through indigo, periwinkle, sage and
pale amber with linear-light interpolation. Turning Max off cancels the task
and disables capture. Session leases prevent an old cancelled task from
disabling a newer session; one actor prevents concurrent ring readers.

Apple references: [audio spectrogram example](https://developer.apple.com/documentation/accelerate/visualizing-sound-as-an-audio-spectrogram)
and [vDSP FFT](https://developer.apple.com/documentation/accelerate/vdsp_fft_zip).

## Validation

- **50 core tests pass**, including calibrated sinusoidal power, frequency
  placement from 20.5 Hz to 18 kHz, stereo phase independence, silence,
  bit-exact capture, overflow protection, hop timing and discontinuity resets.
- Independent NumPy FFT comparison: relative PSD error **8.38e−8**. Integrated
  spectral density and window-weighted time-domain power agree within
  **1.12e−10** for the production noise sample.
- The host Mac processes 60 seconds of stereo analysis in **0.556 seconds**.
  This excludes Swift image generation and device GPU/battery work and is not
  a physical-device performance claim.
- Concurrent capture stress: **25.6 million source frames**, **24,204,288**
  checked frames, with **703,744** deliberately dropped visual frames during
  consumer stalls. Sample content and source order remain correct. Undefined
  behavior and bounds sanitizers pass.
- **31 iOS and 10 tvOS integration tests pass**. Enabling/disabling capture
  leaves the audio engine running and its sample clock advancing; disabled
  capture stops publishing samples.
- Existing Low/Med/High UI behavior passes. New phone and TV UI flows verify
  Off/Max, measured frame advancement, pause, uninterrupted sound while changing
  visual modes, and saved preferences. The phone Off artwork remains identical
  between screenshots. Pause permits only the display pipeline's 1–2 byte-value
  color-conversion rounding, with no colored pixels by the existing criterion.
- Early UI attempts used a debug counter hidden by accessibility grouping and
  demanded exact RGB byte equality across native compositing. The counter is
  now in the chart's debug accessibility value; the grayscale check uses the
  established perceptual threshold after the existing color transition settles.
  The original failed logs and corrected passing results are retained locally.

- The same Off/Max/pause/persistence UI flow passes on a 13-inch iPad Pro.
  Phone, tablet and TV screenshots were visually inspected.
- Signed iOS and tvOS packages pass strict signature verification, have
  distribution entitlements and background audio, and report version 1.1,
  build 26. Source and package hashes are in
  [build-26-manifest.json](build-26-manifest.json). Archives use the existing
  unsigned-archive / distribution-signed-export workflow because the account
  has no registered development devices.

Physical-device listening, overnight playback and battery measurements have
not been repeated for this visual update.

## Reproduce

Run `swift test` and the affected Xcode integration/UI tests. For the independent
PSD check, compile `BrownNoiseDSP.c`, `BNMixRenderer.c`, `BNCapture.c` and
`BNSpectrum.c` into `build/spectrogram/libAudit.dylib` with the public include
directories and `-framework Accelerate`, then run
`python3 scripts/check-spectrogram.py`.

Compile `BNCapture.c` with `scripts/check-spectrum-capture.c` and
`-fsanitize=undefined,bounds` to run the producer/consumer stress audit.
The build manifest records source and signed-package hashes.
