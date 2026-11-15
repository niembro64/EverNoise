# EverNoise 1.0.1 — living infinity, build 12

The infinity is now a larger liquid ribbon with visible internal light currents,
a soft membrane, and close, diffuse mist. Its over/under crossing adds depth.
The black screen and existing dot controls remain simple.

## Motion and continuity

- Native Metal shading draws the entire 160-by-90-point mark. Continuous sine
  fields move the light and mist; there are no particles spawning or disappearing.
  The principal current takes approximately 16 seconds to circulate.
- A three-stage exponential smoother preserves value, velocity, and acceleration
  when play/pause or color targets change, including rapid repeated taps. Exact
  integration makes the trajectory independent of the display frame interval.
  A monotonic clock avoids wall-clock changes. Integer harmonics make the
  240-second phase wrap seamless and avoid an indefinitely growing Float clock.
- Playing starts gradually. Pausing or setting all bands off eases the current
  to rest and fades to grayscale. After four seconds the remaining motion is
  below 0.00001 points of travel; the display then becomes exactly still.
- Hiding the app or opening help suspends the animation. It returns at the same
  position and gradually accelerates. Reduce Motion leaves a still mark, with
  color retained while playing. SwiftUI schedules at most 60 updates per second.
- The play/pause symbols crossfade in place. Picker colors and selection borders
  fade instead of switching abruptly.
- All ten audio, DSP, and lifecycle sources match build 11 byte for byte. Visual
  rendering neither reads audio samples nor changes the audio engine.

## Verification

The final run passed **12 tests** in
`build/release-v12/Final-IntegrationAndUI.xcresult`: five real-engine integration
tests, five analytic motion tests, and two UI tests. The engine tests exercise
playback and mix changes; the lifecycle UI test verifies 15 seconds of background
rendering without an engine restart, persistence, and all controls. Motion tests
cover rapid retargets, frame-rate independence, imperceptible final settling,
twelve simulated hours hidden, and paused/Reduce Motion stillness.

UI screenshot-pixel comparisons confirm visible motion while playing, exactly
still imagery after pausing, and grayscale when paused or all bands are off.
Release iPhone and iPad layouts, paused screenshots, a motion recording, and both
actual uploaded Apple screenshot previews were visually inspected. The final
recording is `build/release-v12/flow-final.mp4`; its contact sheet is
`flow-final-frames.png`. The first visual prototype had visible joins at the
loop tips; those were removed before the final validation and package.

The initial test run encountered a simulator host audio failure (HAL audio device
reported a zero sample rate). It failed one audio-engine test while both
simulators were running. After shutting down the unused iPad simulator, the full
final test run passed without changing audio code. This is recorded as an initial
environment failure, not as proof of an app audio fix.

Xcode initially lacked Apple's Metal Toolchain; the official component was
installed successfully. Release simulator/device builds, unsigned archive,
cloud-signed export, strict code-signature verification, identity, background
audio mode, and distribution entitlements passed. The packaged Metal library is
present, and packaged infinity icons match build 11. The signed package and all
26 production source/asset hashes are in `build-12-manifest.json`.

This is simulator and source-level validation. No physical-device frame-rate,
battery, thermal, listening, or overnight playback result is claimed.

## Version and distribution

Apple approved version 1.0 (build 11) while this update was being prepared.
Its App Store Connect status became **Ready for Distribution**, and Apple's US
storefront lookup returned **EverNoise, 1.0, price 0.00**. The existing version is
public at <https://apps.apple.com/us/app/evernoise/id6834413344>.

The first upload of build 12 used marketing version 1.0 and was rejected because
that version's release train had closed. Only the marketing version and generated
project metadata changed to 1.0.1 after the passing tests. The app, audio, and
shader sources are identical to the tested sources. The rebuilt 1.0.1 (12)
package uploaded successfully on November 14 at **19:28:57 UTC**.

TestFlight notes showed **Saved**. Personal Testing shows **1.0.1 (12), Testing**,
with the existing one tester. The last installed build observed was **1.0 (11)**.
See `testflight-confirmation.json`. Build ID:
`a34adafa-699a-43f7-b535-9b901cbc245b`.

Current App Review state is recorded in `submission-confirmation.json` and
`RELEASE_STATUS.md`. Version 1.0's approved submission record and prior metadata,
notes, screenshots, and deployment records are preserved with the `-v11` suffix.

## Support site

The support site describes the liquid current and gradual transitions. All 12
live assets match source across `/evernoise/`, `/endless-noise/`, and
`/just-brown-noise/` after Cloudflare email decoding. The atomic deployment
verified 189 files and preserved all 177 unrelated files. The previous release
remains available for rollback; see `support-deployment.json`.
