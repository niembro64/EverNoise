# EverNoise circle stops and scale windows — build 21

Each frequency rail now shows five solid, soft-white circles, 9 points across. The selected circle remains visible inside a 52-by-44-point glass window with a small inward downward pointer. The 10-point gradient rail preserves the dark-left/bright-right direction. All five circles use the same clear shape; Off is the leftmost stop and is announced explicitly by VoiceOver.

The window uses native `UIGlassEffect(.clear)` on iOS 26 and system material on older systems. The stationary marks render in a separate view above the glass, preventing blurred or doubled dots from refraction. The pointer stays neutral white and does not depend on band color. A subtle rim defines the window on black, and both endpoints retain two points of clearance around its full outline. The entire row keeps a 56-point touch height; users can tap the rail or drag the window rather than aiming at a tiny circle.

UIKit's public thumb/track-image and geometry hooks retain slider semantics and touch tracking. No private view hierarchy is inspected or altered. The selected sound is quantized to the existing five values while dragging; release settles the window onto the nearest circle with a 240 ms ease and no overshoot. VoiceOver moves one stop at a time. Low animation mode and Reduce Motion suppress the app-controlled settling animation. Unchanged values avoid reassigning the window during artwork refreshes.

Two visual prototypes were rejected before testing/upload: a full material blurred the selected circle, and a masked/reordered layer approach produced incomplete simulator composition. The final implementation uses ordinary sibling UIViews, an unmasked native glass effect, and a separate crisp-mark overlay. Final visual and pixel checks cover the corrected composition.

The audio engine, DSP, logarithmic power values, saved mix, stereo behavior, animation settings, and original five-button components are unchanged. Release validation and delivery evidence are recorded in `build-21-manifest.json` and `RELEASE_STATUS.md`. No physical-device overnight or battery result is claimed.

Primary API references: [Apple UISlider appearance customization](https://developer.apple.com/documentation/uikit/uislider) and [UIGlassEffect](https://developer.apple.com/documentation/uikit/uiglasseffect).

All 30 integration/UI tests passed in one run: 25 integration tests and five UI tests. Final Release phone/tablet screenshots and paused grayscale were visually inspected. Fresh defaults, signing, distribution entitlements, background audio, original-button preservation, and source/package hashes pass. All 12 support assets are verified live; 177 unrelated files were preserved. Native controls were exercised on iOS 26.2; the older-OS fallback was compiled but not run on an older OS this turn.
