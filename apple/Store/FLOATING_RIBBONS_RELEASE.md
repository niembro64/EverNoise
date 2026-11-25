# Larger infinity and floating ribbons — build 16

Version 1.0.1 (16), November 14, 2026. `RELEASE_STATUS.md` separates local validation, upload, TestFlight availability, and App Review submission.

## Result

- The liquid infinity fills the upper screen responsively: 354 by 199.125 points on the tested phone and 984 by 553.5 points on the tablet. The pickers remain bounded to 420 points; play/pause stays visible on the tested portrait layouts, and a scroll view supports smaller layouts and larger text.
- Four large, faint closed ribbons now occupy the full background. Gentle shader-based drift, turning, depth changes, and bending create a slightly faster floating motion. The former top-only mask is removed. Foreground and background share the liquid material, rainbow distribution, clock, and fixed-viewport renderer.
- The visible gear stays 22 points, with an 80 by 80 point touch target. Selected Low/Mid/High borders increase from 2 to 4 points; unselected borders remain 1 point.
- Foreground rendering is capped at 768 pixels wide on phone and 1024 on tablet; background is capped at 640 and 768 respectively. Texture dimensions and SwiftUI transforms stay fixed during animation. Foreground uses sRGB compositing to preserve its prior brightness; the faint background retains linear compositing.
- All 14 audio, playback-lifecycle, smooth-clock, and palette source files match build 15 byte-for-byte. Stereo defaults on while honoring saved choices. Sound generation, levels, transitions, and background playback are unchanged.

## Motion measurements

`scripts/check-ribbon-motion.swift` compiles the actual production shader body and reads the production palette. It sampled 2,436 full-raster frames across phone/tablet foreground/background surfaces at 60 Hz, including five epochs, the four-minute wrap, repeated identical inputs, and explicit 0/2π endpoint comparisons. Existing pass thresholds were retained.

| Surface | Maximum frame delta | Maximum second difference | 0/2π difference | Host GPU p95 |
| --- | ---: | ---: | ---: | ---: |
| Phone background | 0.00360107 | 0.00168610 | 0.00012207 | 2.369 ms |
| Tablet background | 0.00335693 | 0.00146484 | 0.00012207 | 2.497 ms |
| Phone infinity | 0.00891113 | 0.00390625 | 0.00048828 | 0.460 ms |
| Tablet infinity | 0.00891113 | 0.00537109 | 0.00048828 | 0.791 ms |

All values remain finite and bounded. Every background vertical third contains visible ribbon pixels. Identical inputs produce identical pixels. Endpoint tolerances account for floating-point trigonometry and half-float quantization. These are Apple M1 Max shader measurements, not physical iPhone frame cadence or battery measurements. SwiftUI compositing was visually checked separately in the final Release captures.

## Validation

All 20 distinct integration/UI tests passed across the full run and one targeted rerun: seven engine, one preference, one conversion, seven motion/palette, and four UI tests. The first run passed 19 tests; its animation-off pixel sample overlapped the newly enlarged foreground infinity. Moving that background-only sample to the lower outer gutter corrected the test, and the targeted rerun passed without changing application code or relaxing thresholds. The same lower-screen region passes visibility and movement checks while animations are enabled.

UI checks verify the larger infinity, reachable playback control, an 80-point gear target tapped outside the visible icon, all five values in each picker, native green/neutral switch states, preference persistence, six hue families, grayscale pause, and exact stillness with animations off. Backgrounding, changing stereo, and changing bands preserve the running audio engine.

Final Release phone/tablet layouts, Settings, and sampled video frames were visually inspected. Archive and signed export succeeded. Strict signature, version/build identity, background audio, distribution entitlements, compiled Metal, and unchanged infinity icons passed. The support site was published and all 12 live assets verified; 177 unrelated files were preserved.

Test evidence: `build/release-v16/Validated-IntegrationAndUI.xcresult` (19 passed, one obsolete sample region) and `Final-VisualPreference.xcresult` (corrected test passed). Source/package hashes are in `build-16-manifest.json`. External release state is recorded separately in `RELEASE_STATUS.md`.

## Artifacts

- Final archive: `build/JustBrownNoise-v16-final.xcarchive`. The earlier `JustBrownNoise-v16.xcarchive` predates the foreground compositing correction and must not be uploaded.
- Signed package: `build/AppStore-v16/JustBrownNoise.ipa`.
- Motion evidence: `ribbon-motion-v16.json`, `build/release-v16/motion-audit.log`.
- Release captures: `build/release-v16/phone-release.png`, `tablet-release.png`, `ribbons-release.mp4`, and `motion-contact.png`.
- Store copy and beta notes: `metadata-v16.json`, `TestFlight-notes-v16.txt`.

Build 14's extended audio measurements remain the baseline for the unchanged production DSP: 37 core tests, 199 engine renders, and 30 accelerated source hours per band. These were not rerun as build-16 results. Physical-device overnight listening, frame cadence, thermal behavior, and battery consumption remain unmeasured for this build.
