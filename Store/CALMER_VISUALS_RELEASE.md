# Calmer visuals and default stereo — build 15

Version 1.0.1 (15), November 14, 2026. See `RELEASE_STATUS.md` for the separately confirmed TestFlight and App Review states.

## Result

- Stereo starts on when no preference exists. A saved Off or On remains unchanged. Only the initial default changed in the audio service/driver; all production DSP and PlaybackCore files match build 14 byte-for-byte.
- Native Stereo and Animations switches use a soft green on state and gray off state.
- The title uses the light rounded system font. Low, Mid, and High use muted rose, sage, and periwinkle. A shared six-hue palette uses matching OKLCH lightness/chroma (L 0.60, C 0.085) and supplies both controls and ribbon material. Existing logarithmic audio levels and rainbow power weighting remain.
- Four enormous, faint background loops render in one fixed viewport. Inverse mapping performs drift, rotation, and bending inside Metal before rasterization. The prior separately magnified, rotated, and repositioned SwiftUI images are removed. Magnified raster/layout steps were a plausible source of the reported jitter, not a confirmed physical-device diagnosis.
- Background resolution is capped in pixels (640 phone, 768 tablet), with a static final scale. Shared material flow and background drift/rotation are slower. The animation clock and smooth state transitions remain independent of audio.

Apple documents the [offscreen rendering performed by drawingGroup](https://developer.apple.com/documentation/swiftui/view/drawinggroup(opaque:colormode:)) and the [display-scale environment value](https://developer.apple.com/documentation/swiftui/environmentvalues/displayscale) used to keep this pixel budget stable.

## Validation

`build/release-v15/Validated-IntegrationAndUI.xcresult` passed all 20 tests: seven real-engine, one preference, one conversion, seven motion/palette, and four UI tests. Tests exercise absent/default-on preferences, saved Off/On, a live stereo change without an engine restart, pause/background behavior, all six muted hue families, animation movement, and exact stillness while paused or animations are off. Actual switch pixels verify green On and neutral Off.

The first test run exposed a command-line UserDefaults string conversion bug, fixed by using `bool(forKey:)` after checking key presence. Pixel classifiers were updated for the deliberately muted hues. Background movement is now smaller than the old greater-than-two-byte change threshold; the check counts every changed byte and still requires more than 100 changes. Paused/off stillness checks were strengthened to require zero changed pixels.

`scripts/check-ribbon-motion.swift` compiles the actual production shader body on the Apple M1 Max, reading its palette from the production Swift file. It samples 1,827 full-raster frames at 60 Hz across ordinary phases and the four-minute wrap, plus identical-phase and explicit 0/2π endpoint comparisons. All values remain finite and bounded. See `ribbon-motion-v15.json` for measurements and source hashes.

| Surface | Maximum frame delta | Maximum second difference | 0/2π endpoint difference |
| --- | ---: | ---: | ---: |
| Phone background | 0.00152588 | 0.00054932 | 0.00012207 |
| Tablet background | 0.00155640 | 0.00057220 | 0.00006104 |
| Infinity | 0.00878906 | 0.00585938 | 0.00048828 |

Values use normalized color/alpha units. The background maximum frame delta is below one 8-bit step. Explicit endpoint tolerance accounts for float trigonometry and half-float output quantization; an initial 0.0001 background bound was below the observed 0.00012207 representable difference and was corrected to 0.00025. The independent frame/second-difference checks also cross the wrap and pass. Identical inputs produce identical pixels. Host GPU timings are recorded, but are not physical iPhone frame cadence or battery measurements.

Release iPhone and iPad layouts, Settings On/Off states, and sampled frames from a Release simulator recording were visually inspected. The final archive/export/upload succeeded. Strict signature, build/version identity, background-audio mode, distribution entitlements, compiled Metal, and unchanged infinity icons passed.

Build 14's 37 core tests, 199 engine renders, and 30 accelerated hours per band remain the audio baseline for these unchanged DSP sources; those extended runs were not repeated or claimed as new build-15 results. Physical iPhone smoothness, stereo listening, overnight continuity, thermal behavior, and battery consumption remain unmeasured for this build.

## Artifacts

- Final archive: `build/JustBrownNoise-v15-final.xcarchive` (the earlier unsigned-v15 archive predates the preference fix and is not the uploaded archive).
- Signed package: `build/AppStore-v15/JustBrownNoise.ipa`.
- Production/test/package hashes: `build-15-manifest.json`.
- Motion evidence: `ribbon-motion-v15.json` and `build/release-v15/motion-audit.log`.
- Release captures: `build/release-v15/phone-release.png`, `tablet-release.png`, `ribbons-release.mp4`, and `motion-contact.png`.
- Store copy and beta notes: `metadata-v15.json`, `TestFlight-notes-v15.txt`.
- Support: `support-deployment-v15.json`; all 12 live assets verified, 177 unrelated files preserved.
