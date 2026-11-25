# EverNoise — shared rainbow ribbons, build 13

The infinity retains the fully mixed body color and now contains six distinct
color-wheel currents: red, yellow, green, cyan, blue, and magenta. Two much larger,
fainter closed loops drift and bend behind the top of the screen. An Animations
switch in the info sheet saves a preference for a still infinity and plain black
background. Sound continues independently.

## Shared implementation

- `RibbonPalette` preserves the established mixed body color. Spectral weighting
  uses band power: Off, 10^(-18/10), 10^(-12/10), 10^(-6/10), and 1. A small
  baseline preserves every hue; secondary-color weights use smooth harmonic
  means of their neighboring primary bands. Six-decibel steps are power ratios,
  not linear picker indices or amplitude ratios.
- `RibbonScene` owns one monotonic clock, one smooth palette, and one motion
  state for every ribbon. `FluidMotion` retains the tested gradual start/stop,
  continuous value/velocity/acceleration, seamless phase wrap, and hidden-state
  behavior. Colors and band power follow the same analytic smoothing.
- `RibbonSurface` uses `RibbonShaders.metal` for both the foreground infinity
  and background loops. All share the same `shade` material, spectrum, filament
  flow, membrane, lighting, and mist. Only geometry, depth, size, and opacity vary.
- Background paths are periodic closed curves with analytic tangents/curvature.
  Harmonics gently change their shape and position; no endpoints, particle
  creation, random frame changes, or geometry resets are used. Deeper layers
  are larger, fainter, and slower. A vertical fade keeps the controls quiet.
- Background materials render in two 200-by-128-point offscreen surfaces before
  enlargement, rather than shading the full display at native resolution. The
  shared clock requests at most 60 updates/second. Actual device cadence and
  battery consumption have not been measured.
- `@AppStorage("animationsEnabled")` is shared by the info sheet and main view.
  Off removes the background, freezes the infinity, disables custom control
  fades, and pauses the timeline immediately; no settling timer remains active.
  Static colors still reflect mix/playback changes. Turning animations on eases
  the flow back in. Reduce Motion also hides background loops and rests the mark.
- All ten audio/DSP/lifecycle source files match build 12 exactly. No visual code
  samples audio or controls playback. The installed infinity icon is unchanged.

## Validation

**All 15 final tests passed** in
`build/release-v13/Final-IntegrationAndUI.xcresult`: five real-engine tests,
seven motion/palette tests, and three UI tests.

The new UI checks require visible pixels from all six hue families inside the
infinity, visible motion in a separate background region, exact stillness when
animations are off, removal of background color, persistence across relaunch,
and continuing audio without an engine restart. Existing checks cover paused
and all-off grayscale, playing motion, all controls, saved band settings, and
15 seconds of background rendering without an engine restart.

The first settings test tapped the middle of SwiftUI's labeled switch row,
which did not operate the trailing switch. The test was corrected to tap the
actual switch. The final full run passed; no production settings workaround
was needed. Initial shader accents blended some hues into the mixed body too
strongly; transmitting their own color through narrow cores made all six hues
visible before final validation. A hard safe-area crop was also removed before
the final run.

The final motion recording is `build/release-v13/ribbons-final.mp4`; a contact
sheet is `ribbon-final-frames.png`. Final test screenshots include the info
switch, disabled still view, playing colors, grayscale pause, and all-off.
Release iPhone/iPad layouts, the final info switch, and both actual uploaded
Apple device previews were visually inspected. Both previews show the new ribbons
and the correct infinity app icon.

Release builds, archive, cloud-signed export, strict signature, version/bundle,
background audio, distribution entitlements, packaged infinity icons, and Metal
library were checked. `build-13-manifest.json` records 28 production source/asset
hashes, test hashes, and the signed package hash. Physical-device overnight,
listening, frame-rate, thermal, and battery measurements are not claimed.

## Release evidence

Build 13 uploaded successfully at 14:00:26 CST on November 14, 2026.
Personal Testing shows **1.0.1 (13), Testing**, with saved notes and one tester.
Apple confirmed **1 Item Submitted** at 14:08 CST and **Waiting for Review** for
submission `adc6953d-f45c-4c22-99b5-5dc273e805eb`, replacing the canceled build-12
submission. Automatic release is selected. The public release remains version
1.0; this new update is available now through TestFlight.

See `testflight-confirmation-v13.json`, `submission-confirmation-v13.json`, and
`RELEASE_STATUS.md` for separately verified TestFlight and App Review states.
Build-12 records remain in their `-v12` files. Support deployment and live asset
checks are recorded in `support-deployment.json`.
