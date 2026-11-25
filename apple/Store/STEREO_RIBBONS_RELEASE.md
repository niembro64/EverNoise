# EverNoise — larger ribbons and optional stereo, build 14

Four closed background ribbons are now 2.8, 3.6, 4.6, and 5.6 times the
screen's capped reference width. Their opacity ranges from 9% down to 2.8%.
They mostly extend beyond the top and sides of the screen; deeper loops are
larger, fainter, and slower. All four retain the infinity's shared material,
six-color distribution, smooth motion, and low-resolution offscreen rendering.
The outline gear opens Settings, which includes Stereo, Animations, privacy,
and help. Animation-off, grayscale pause, and Reduce Motion remain supported.

## Stereo and continuity

Stereo is false when no preference is saved. Each band owns two separately
seeded generators, each with its own original linear filters and state. When
off, both channels receive the original left samples exactly. When on, the
right channel receives its independent source with the same band levels.
Both source clocks remain warm even while a band is off or mono is selected.

A one-second quintic crossfade changes only the right channel; the left
sequence is untouched. Its convex blend cannot exceed the existing source
bounds. Intermediate right-channel power can briefly dip by up to 3 dB as
uncorrelated sources overlap; settled modes have the same per-channel power.
There is no limiter, compressor, AGC, peak normalization, or new nonlinear
waveform shaping. A mono device cannot reproduce separation and may average
the two independent signals at a lower power.

Both channels exist in the permanent engine graph. The switch posts lock-free
commands without allocations, session activation, graph changes, or engine
restart. Band/pause envelopes use one control snapshot per pair. Render code
performs no allocation, locking, I/O, or work on the UI thread. Changing the
option while paused keeps playback paused. The preference survives relaunch
and engine reset. Existing interruption and playback recovery policy is retained.

### Explicit conversion compatibility difference

An initial old/new engine comparison correctly failed the assumption of bit
identity at every rate. Apple's legacy mono-source conversion attenuated
44.1 kHz by 3.0103 dB, already measured in the build-2 audit. The permanent
two-channel path does not add this attenuation. On macOS and iOS 26.2 Simulator,
the new output has the same waveform after one constant sqrt(2) factor at
44.1 kHz (maximum residual below 1e-6). At 16, 48, and 96 kHz, the iOS brown
reference is bit-identical. All 48 kHz macOS band/mix reference cases are also
bit-identical. The conversion test now explicitly checks this documented gain
difference and rejects changes to waveform shape.

The implementation retains the calibrated source gains at all rates instead
of adding OS/rate-specific compensation guesses. Consequently a 44.1 kHz route
can sound about 3 dB louder than an older build at the same hardware volume.
This difference is included in TestFlight notes. Stereo toggling itself does
not change the conversion graph or settled per-channel gain.

## Audio validation

- 37 core tests pass, including all bands/levels in mono, independent stereo
  sequences, crossfades and reversals, arbitrary callback partitions,
  interleaved/planar channel layouts, saved modes, and seed edge cases.
- 199 actual AVAudioEngine offline renders cover all 125 stereo mixes, four
  output rates (16/44.1/48/96 kHz), mono/stereo outputs, rapid mode and band
  changes, deliberate mute, and 20 old/new reference comparisons. No render
  retries occurred. Non-silent steady playback had no silent buffers.
- Maximum estimated 4x intersample peak: 0.208323, or 13.63 dB of measured
  headroom. Maximum absolute L/R correlation: 0.02563; maximum L/R power
  difference: 0.114 dB. Independent per-band spectra agree within 0.072 dB.
- Thirty accelerated hours per band passed with repeated mode changes, no
  silent buffers or invalid samples, bounded peaks, and exact 64-bit frame
  counts. Brown: 864,000,000 frames; Mid and High: 5,184,000,000 frames each.
  This is source endurance, not a 30-hour physical-device playback observation.

Machine-readable measurements: `stereo-measurements-v14.json`. Raw renders,
initial failure evidence, endurance logs, and test bundles are retained in
`build/release-v14/`. Device listening, overnight continuity, thermal behavior,
and battery consumption have not been measured for build 14.

Release and simulator builds, signed export, strict signature, bundle/version,
background audio, distribution entitlements, packaged infinity icons, and
compiled Metal library have passed inspection. Release-state confirmations
are recorded separately after Apple confirms them.

All 19 final iOS tests passed: seven real-engine lifecycle/stereo tests, one
conversion comparison, seven motion/palette tests, and four UI tests. UI checks
cover default-off Stereo, persistence on/off, mode changes without restarting
the engine, preservation of pause, background source-clock progress, all six
color families, moving foreground/background, grayscale pause, and exact
stillness with Animations off. Final release phone/tablet layouts and Settings
were visually inspected. A sampled sequence from the 27-second simulator recording shows
the subdued loop motion (`build/release-v14/ribbon-frames.jpg`); a full recording
is beside it. Device frame rate and battery impact remain unmeasured.

Apple accepted the upload at 14:42:20 CST. Personal Testing shows **1.0.1 (14),
Testing**, one tester, with Saved test notes. The observed installed build is
still 1.0.1 (13). The live support aliases match all 12 reviewed assets and
preserve 177 unrelated files. Current submission status is recorded in
`RELEASE_STATUS.md` and the versioned confirmation JSON files.
