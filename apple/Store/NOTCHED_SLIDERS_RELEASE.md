# EverNoise five-stop controls — build 20

## Changes

- Settings uses a native segmented **Audio: Mono / Stereo** picker matching Animations. It binds to the existing saved stereo preference; Stereo remains the fresh-install default.
- Low, Mid, and High use Avenir Next Ultra Light, matching the title, at 28 points with Dynamic Type.
- `BandNotchPicker` replaces each button row with a native slider, a 56-point touch target, a dark-to-muted-color rail, and five detents. Tap anywhere along the rail or drag its native thumb. The left end is Off and the right is full strength. There are no new intermediate sound levels.
- iOS 26 uses `UISlider.TrackConfiguration(allowsTickValuesOnly: true, numberOfTicks: 5)` and its native ticks/thumb. Earlier systems use our notch marks and snap on release. VoiceOver adjusts exactly one notch and announces Off or 1–4 of 4.
- The rail interpolates decoded linear-light colors using 65 explicitly sRGB-encoded samples. It drains to grayscale when paused/all-off and obeys Low/Reduce Motion for app-controlled transitions.
- The entire original five-button component, including its intensity symbols, remains in `App/BandPicker.swift`. Only its access level changed for use from another file. Both components share the updated band-heading font.

## Sound preservation

Only the integer levels 0–4 enter `AudioService.selectMix`. The existing Off / −18 / −12 / −6 / 0 dB mapping and 600 ms sound fades are unchanged. Audio mode still uses the existing independent left/right generators and one-second stereo fade. All ten audio/DSP/lifecycle files are byte-identical to build 19. The compiled Metal library and infinity icon also match build 19.

## Validation

The first completed run passed 24 integration tests and four of five UI tests. Its only UI failure caught UIKit reducing the slider's touch target to 34 points. Explicit view sizing and intrinsic height now keep it at 56 points. All three affected interaction and pixel tests passed after this fix, including the full 15-choice lifecycle flow, between-stop drags, taps above the rail, and paused/all-off grayscale. All 29 distinct tests pass across the two runs. Two earlier attempts failed to compile test-only code (an optional configuration and a shadowed helper); both were corrected before these runs.

Coverage includes all 15 band/stop selections, taps and drags between stops, both endpoints, VoiceOver increments and boundaries, independent band persistence, Mono/Stereo persistence while playing and paused, no audio engine restart, and render counters advancing in a 15-second background smoke test. Visual checks cover paused/all-off grayscale and the three animation levels. These simulator checks are not an overnight physical-device or battery measurement.

Primary API reference: [Apple UISlider TrackConfiguration](https://developer.apple.com/documentation/uikit/uislider/trackconfiguration-swift.struct) and [iOS 26 UIKit controls](https://developer.apple.com/videos/play/wwdc2025/284/?time=835).

Release and portal status are recorded separately in `RELEASE_STATUS.md`, `build-20-manifest.json`, and the upload/TestFlight confirmations. App Store Connect browser access was unavailable this turn; listing text, screenshots, and beta notes are prepared locally.

Final Release iPhone 17 Pro and iPad Pro 13-inch layouts, both Audio segments, and paused grayscale were visually inspected. Fresh installs retain Med by default. Native controls were exercised on iOS 26.2; the older-system fallback was compiled but not run on an older OS in this turn. Strict package signing, distribution entitlements, background audio, icon/Metal preservation, and source hashes pass. All 12 support assets are live, with 177 unrelated files preserved.
