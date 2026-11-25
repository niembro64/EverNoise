# Linear light, Liquid Glass, and typography — builds 17 and 18

This release makes the artwork's color pipeline explicit, adds native iOS 26 Liquid Glass controls, gives the rear infinity surface more depth, and adopts Avenir Next throughout the interface. External upload, TestFlight and App Review states are recorded separately in `RELEASE_STATUS.md`.

## Color policy

Authored colors use sRGB. Before any color addition, interpolation, light weighting, or intensity scaling, the app decodes each component with the exact piecewise sRGB transfer function. The familiar square/square-root technique is only a gamma-2 approximation. Alpha represents coverage/transmittance and is never gamma corrected.

The linear premultiplied source-over operation is:

```
RGBout = RGBfront + RGBback * (1 - alphaFront)
alphaOut = alphaFront + alphaBack * (1 - alphaFront)
```

The former foreground/background color-space mismatch is removed. A single opaque Metal surface composites the infinity, mist, and all background loops in linear light, then composites onto black. The shader explicitly applies the exact sRGB encoding once to the completed opaque scene. Its SwiftUI drawing group uses nonLinear mode for that already encoded image; no translucent encoded ribbon layers are handed back to SwiftUI. Native controls remain outside the offscreen canvas so Liquid Glass can sample the scene behind them.

RGB brightness no longer determines alpha. Body and mist each carry their own premultiplied RGB and opacity. Mist uses `1 - exp(-opticalDepth)` for opacity. Colored light contributions add according to the bands' logarithmic powers. A single hue-preserving SDR shoulder maps the completed scene into display range; that restrained brightness mapping is an artistic choice after linear composition, not a claim of a full spectral or volumetric fluid simulation.

The rear infinity half smoothly reaches 42% of the front's linear radiance and 0.62 body opacity versus 0.90 at the front. Its shading and opacity join continuously at both tips. Shared-tip geometry is treated as one surface; alpha and RGB use the same smooth transition. Build 18 limits merging to samples that converge on the same geometric tip, with a C2-continuous blend. Separate portions retain source-over composition of their mist. This removes the equidistant-centerline seam discovered in the final build-17 iPad preview.

Primary references:

- [W3C: color spaces appropriate for physically mixing lights](https://www.w3.org/TR/css-color-4/#interpolation-space)
- [W3C: exact sRGB transfer functions](https://www.w3.org/TR/css-color-4/#color-conversion-code)
- [W3C: premultiplied source-over and union alpha](https://www.w3.org/TR/compositing-1/#simplealphacompositing)
- [Apple: colorEffect receives and returns premultiplied color in its destination color space](https://developer.apple.com/documentation/swiftui/view/coloreffect(_:isenabled:))

## Controls and type

`NoiseGlassButtonStyle` uses Apple's `glassEffect` with a tinted regular material and native interactivity on iOS 26. Controls share a `GlassEffectContainer` whose spacing keeps individual picker buttons separate. The native Settings toolbar and switches remain system components. Earlier iOS versions use a system-material fallback. Custom interaction animation is disabled with the saved animation preference or Reduce Motion.

The 80-point gear hit target, 112-point play/pause target, and 4-point selection borders are retained. Avenir Next Ultra Light, Regular, Medium, and Demi Bold provide the title, body, band labels, and headings; all text styles retain Dynamic Type scaling. No font download or new dependency is required.

Reference: [Apple: applying native Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views).

## Validation artifacts

- `scripts/check-color-compositing.swift`: independent numeric probes against production Metal source-over, alpha, exact sRGB decoding, Beer-Lambert transmittance, rear depth, and shared tips.
- `IntegrationTests/ColorCompositingTests.swift`: transfer-function reference values, band-energy addition, shader/display boundary, available font faces, and accessibility scaling.
- `scripts/check-ribbon-motion.swift`: production GPU rendering at 60 Hz, including the four-minute phase wrap, complete phone/tablet scenes, and individual layers.

Build 17 passed all 24 distinct integration/UI tests: 20 integration and three UI tests in `Final-IntegrationAndUI.xcresult`, then the remaining visual test in `Final-PlaybackVisuals.xcresult`. The first UI pass exposed an undersized play hit area, which was fixed. Explicit desaturation handles native glass when paused. Native glass still contributes at most a handful of edge pixels with tiny chromatic fringes; the final control check permits at most 20 pixels with a maximum channel spread of 6/255. Artwork grayscale and paused/animations-off stillness retain exact checks. The observed failing strict-zero runs had only six/four such control pixels with spread at most 5/255.

Nine numeric production-GPU probes passed at 0.000002 tolerance. A separate iOS rendering check passed the actual display boundary: 50% linear white encodes to 188/255 sRGB, within two code values. Font availability and Dynamic Type scaling passed. All 3,654 build-17 motion frames passed, including phase wrap, identical inputs, full scenes, and individual surfaces.

Final enlarged iPad QA caught a spatial mist seam that temporal checks did not cover. Build 18 adds 6,252 GPU comparisons across the equidistant line at twelve phases. The build-17 shader fails this new regression with a maximum discontinuity of 0.131066; the corrected shader passes at 0.000192, below the 0.0005 bound. The exact nine color probes also continue to pass. All 3,654 motion frames pass the unchanged limits. The build-18 playback-visual UI test passes, including grayscale and exact paused/animations-off stillness. The remaining build-17 tests and their implementation subjects are unchanged; this is a targeted rerun, not a new full 24-test run.

Final build-18 Release phone and tablet screenshots show the seam removed and all controls reachable. Five samples from a 16-second recording were inspected. The signed build-18 package passes strict signature, identity, distribution entitlement, background-audio, Metal, and icon checks. Source, test, script, screenshot, release-text, and IPA hashes match `build-18-manifest.json`. Existing derived-data directories were reused for incremental compilation; both versioned archives and exported IPAs remain preserved separately.

The ten audio/DSP/lifecycle sources remain byte-identical to build 16. The build-14 extended audio audit remains the baseline, not a new result. Physical iPhone cadence, listening, overnight continuity, and battery consumption are not measured by these simulator/host-GPU checks.

Build 17 uploaded at 22:51:34 UTC; Apple's 22:53:01 UTC notification confirms it is ready in TestFlight. Native glass, Settings, paused states, Release phone/tablet layouts, and six sampled video frames were inspected. The signed package, background mode, distribution entitlements, compiled Metal library, and infinity icons passed. Public submission is pending an idle Edge window. Build-18 delivery is tracked separately in `RELEASE_STATUS.md`.

Build 18 uploaded at **23:03:32 UTC** and Apple confirmed **ready to test at 23:04:51 UTC**. The portal notes and public App Review replacement are still pending browser access; no public build-18 release is claimed. The US storefront still showed free version 1.0 at 23:03:51 UTC. See `testflight-confirmation-v18.json`, `upload-confirmation-v18.json`, and `public-storefront-v18.json`.
