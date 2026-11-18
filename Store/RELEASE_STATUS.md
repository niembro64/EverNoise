# Release status — November 17, 2026

## Public App Store updates — build 30 submitted on all supported platforms

**iOS 1.1 (30) and tvOS 1.1 (30) are both Waiting for Review.** Apple confirmed
receipt on November 17 at **22:15 CST** for iOS and **22:18 CST** for tvOS
(November 18 at 04:15 and 04:18 UTC). Both are configured to release automatically
after approval; iOS will release to all users immediately rather than in phases.

The universal iOS update covers iPhone and iPad, plus the compatible iPad app
on **Apple silicon Mac** and **Apple Vision Pro**. Their availability checkboxes
remain enabled, and App Store Connect lists version 1.1 as compatible with both.
The current public iOS release remains **1.0.1 (23)** until approval. Apple TV's
first public release was still waiting with build 24; that old submission was
withdrawn and replaced with build 30. Neither new public release is approved yet.

Updated descriptions and review notes cover six mix choices, App Loudness,
peak protection, five visual levels and the output spectrogram. Current iPhone,
iPad and 4K TV screenshots replace the old control layouts. Pricing remains
**free** across the existing 175 countries or regions. TestFlight was unchanged.
No application code changed: all 46 source hashes match the validated build-30
manifest, and the existing uploaded binaries were reused.

- [iOS submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/aff29e07-12ee-4044-a9d1-d6ec12ebc129)
- [tvOS submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/be35dd2c-3d3e-41a6-adab-70a64a489a42)
- [Submission and availability evidence](app-store-submission-v30.json)
- [Submitted metadata](metadata-v30.json) and [screenshot provenance](screenshots-v30/provenance.json)

## Quieter first mix choice — build 30

**EverNoise 1.1 (30) is available in internal TestFlight for iOS and Apple TV.**
Apple confirmed iOS availability at **05:29:36 UTC** and tvOS at **05:31:04 UTC
on November 17** (23:29:36 and 23:31:04 CST on November 16).

Each frequency row now has six choices: Off, −30, −18, −12, −6 and 0 dB.
The new first dot contributes about 16 times less power than the former first
dot. Growing dots and brighter tints encode the power curve. All former mixes
and the default sound are preserved through preference migration. Audio
filters, shared App Loudness and peak protection remain unchanged.

55 core, 39 iOS integration, 17 tvOS integration tests, and four final UI flow
executions across iPhone, iPad and Apple TV pass. Checks cover all 216 mixes at
two loudness offsets, 42 Apple-engine conversions, two accelerated hours and
UBSan/bounds instrumentation. Over 19 million legacy samples per channel match
build 29 exactly. A TV focus section keeps the bottom controls reachable from
every Low choice.

What to Test notes are saved and verified for both platforms. TV build 30 is
**Testing** in Personal Testing and Friends and Family, with automatic tester
notification. iOS build 30 is available to Personal Testing; Apple still blocks
another version-1.1 external beta submission while build 25 is Waiting for
Review. The public App Store submission was unchanged during this update.

See [design and validation](MIX_RESOLUTION_RELEASE.md),
[numerical evidence](mix-resolution-audit-v30.json),
[signed packages](build-30-manifest.json), and [delivery evidence](delivery-v30.json).

## Smooth Max spectrum and App Loudness — build 29

**EverNoise 1.1 (29) is available in your internal TestFlight for iOS and Apple TV.**
Apple confirmed iOS availability at **22:51:20 CST** and tvOS at **22:52:20 CST**
on November 16. Notes are saved on both platforms. TV is **Testing** in
Personal Testing and Friends and Family, with automatic notification enabled.
iOS build 25 remains Waiting for Review, and Apple still prevents submitting
another version-1.1 build for external testing. The public App Store submission
is unchanged.

Max now uses seven overlapping window lengths, 1024 frequency rows, 60 columns
per second, smooth octave-energy weighting, gentle temporal filtering, and
16-bit linear-light images. A fixed perceptual brightness curve replaces the
per-hertz display scale. The setting is now **App Loudness**, with its saved
value preserved. The sound engine is bit-identical to build 28.

107 core/integration tests, affected phone/tablet/TV UI flows, independent
numerical calibration, and undefined-behavior/bounds checks passed. The host's
AddressSanitizer runtime could not initialize; that attempt is not a pass.
Physical-device battery, thermal, and GPU performance remain to be measured.
See [design and validation](SPECTROGRAM_SMOOTH_RELEASE.md),
[numerical audit](spectrogram-audit-v29.json), [packages](build-29-manifest.json),
and [delivery](delivery-v29.json).

## Practical frequency tapers and household guidance — build 28

**EverNoise 1.1 (28) is available in internal TestFlight for iOS and Apple TV.**
Apple confirmed iOS availability at **22:02:23 CST** and tvOS at **22:04:05 CST**
on November 16. Testing notes are saved. TV is **Testing** in Personal Testing
and Friends and Family, with automatic notification enabled. Apple still blocks
another iOS version-1.1 external build until build 25's pending review is approved.
No public App Store submission changed in this release.

The rows now run High, Mid, Low. Shared smooth 30 Hz / 20 kHz edge tapers reduce
impractical sub-bass and preserve the upper audible range. Calibration is updated;
dynamics and saved preferences remain. Settings explains listening for babies,
children and pets, including hearing differences, speaker limits and caregiver
precautions. The prior complete sound is tagged `sound-baseline-build-27`.

All 125 mixes at two offsets, 36 Apple-engine conversions, overload checks,
95 core/integration tests, affected phone/tablet/TV UI flows, and **30 accelerated
hours** pass. The long run had no silent buffers or over-ceiling samples, and
peak protection never needed to engage. Physical-speaker listening and overnight
hardware playback remain unverified. See [design and guidance](FAMILY_SPECTRUM_RELEASE.md),
[measurements](loudness-audit-v28.json), [packages](build-28-manifest.json), and
[delivery](delivery-v28.json).

## Off and output spectrogram — build 26 available in TestFlight

**EverNoise 1.1 (26) is available in internal TestFlight for iOS and Apple TV.**
Apple confirmed iOS availability at **19:05:19 CST** and tvOS at **19:08:10 CST**
on November 16. Notes are saved on both builds. The TV build is **Testing** in
Personal Testing and Friends and Family, with automatic notification enabled.
Apple currently prevents adding iOS build 26 to external groups until build
25's first version-1.1 beta review is approved; build 26 is not queued for that
review. Personal Testing has access now.

Off removes artwork and its ongoing animation/analysis work. Max replaces the
infinity with a calibrated spectrogram of the final generated output. Med stays
the default. Pause freezes and grayscales the chart; hiding it stops analysis.
The audio DSP, mix normalization, Volume offset and peak protection are unchanged.

All 50 core tests, 41 platform integration tests, affected phone/tablet/TV UI
flows, independent FFT comparison and concurrent capture stress checks pass.
Both signed packages verify strictly. Physical-device battery, listening and
overnight measurements were not repeated. This release updates TestFlight;
public App Store submissions were not changed in this work.

Details: [design and validation](SPECTROGRAM_RELEASE.md),
[measurements](spectrogram-audit-v26.json), [packages](build-26-manifest.json),
[delivery](delivery-v26.json).

## Stable mix loudness — build 25 available in TestFlight

**EverNoise 1.1 (25) is available in internal TestFlight for iOS and Apple TV.**
Apple confirmed iOS availability at **18:15:57 CST** and tvOS at **18:16:58 CST**
on November 16. Both uploads, saved testing notes, and group assignments are
verified. iOS external beta testing is **Waiting for Review**. tvOS is
**Testing** in both Personal Testing and Friends and Family, with three invites
shown. Automatic external notification is enabled.

Low/Mid/High now set relative balance at a consistent K-weighted listening
level. Very slow correction, separate linked lookahead peak protection, and a
remembered **Volume offset** preserve smooth control changes. The existing
frequency filters remain. The complete previous app is preserved on GitHub at
`sound-baseline-build-24`.

All 125 mixes at two offsets, 36 Apple-engine conversion cases, overload tests,
45 core tests, iOS/TV integration and affected UI tests, and **30 accelerated
hours** pass. Physical-device listening and overnight hardware playback remain
unverified. TV remote offset selection passes; simulator Settings captures are
inconsistent, so physical-TV visual verification remains open.

This is a TestFlight update. Public submissions remain unchanged: iOS **1.0.1
(23)** is Ready for Distribution and tvOS **1.1 (24)** is Waiting for Review
at the live portal check. Details: [loudness design and validation](LOUDNESS_RELEASE.md),
[measurements](loudness-audit-v25.json), [delivery](delivery-v25.json).

## Apple TV submitted; Mac installed

**tvOS 1.1 (24) is available in internal TestFlight and submitted for App Review.**
Apple confirmed TestFlight availability at **17:04:28 CST (23:04:28 UTC)**.
At approximately **17:11 CST (23:11 UTC)**, App Store Connect confirmed
**1 Item Submitted** for [submission b7ec2504-b05f-42c6-91ca-1afa920be659](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/b7ec2504-b05f-42c6-91ca-1afa920be659).
Automatic release after approval is selected. External beta review was also
submitted for the existing Friends and Family group. TV approval and public
availability are not yet confirmed.

The TV target reuses the build-23 audio engine and shader unchanged, adding a
remote-friendly landscape interface, focus, and Siri Remote Play/Pause support.
All 40 core, 32 iOS integration/UI, and 10 TV integration/UI tests pass.
The TV UI test confirms background clock advancement without an engine restart.
Signed package checks and final Release simulator visual inspection pass.
Physical TV/audio-output and overnight qualification remain unperformed.

The existing **iOS 1.0.1 (23)** release remains public and free. It already supports
iPad; Apple silicon Mac and Vision Pro availability have been enabled. Build 23
was installed through TestFlight on this Mac and remained **Playing continuously**
at the final UI check. Apple Watch is intentionally excluded. See
[TV release](TV_RELEASE.md) and [platform availability](PLATFORM_AVAILABILITY.md).

## Apple silicon Mac and Vision Pro availability enabled

At approximately **16:33 CST (22:33 UTC)**, Mac and Vision Pro App Store availability
were enabled for the existing **1.0.1 (23)** release. Both TestFlight groups also
have Mac and Vision Pro testing enabled. The saved public availability switches
were verified after reloading App Store Connect.

Build 23 was installed through TestFlight on an Apple silicon Mac running macOS
26.6.2. Launch, play/pause, Settings, and return to the playing state passed a
manual smoke test. iPad support was already included. This availability-only
step used the existing binary and changed no audio code. The TV target was
added afterward as recorded above; Watch and Intel Mac have no release.

Details and validation limits: [platform availability](PLATFORM_AVAILABILITY.md).

## Public release confirmed — version 1.0.1, build 23

**EverNoise 1.0.1 (build 23) is live on the App Store for free.** At **15:11:05 CST (21:11:05 UTC)** on November 15, Apple's US lookup service reported version 1.0.1, price $0.00, and release time **14:44:13 CST (20:44:13 UTC)**. App Store Connect separately showed **Ready for Distribution** with build **23** attached.

The current internal tester is shown as having installed build 23. External TestFlight distribution still showed **Waiting for Review**; its beta review is separate from the completed public App Store review. Automatic external tester notification remains enabled. Personal invitation records are kept locally in ignored files.

Evidence: [public release record](public-release-v23.json) and [public App Store listing](https://apps.apple.com/us/app/evernoise/id6834413344).

## Historical preparation and submission — complementary engine, build 23

**Build 23 is available in TestFlight and submitted for App Review.** Apple confirmed TestFlight availability at **09:45:04 CST (15:45:04 UTC)** on November 15. Upload succeeded at 09:43:41 CST. At 09:53 CST, App Store Connect confirmed **1 Item Submitted** for [submission cb3f8064-29c8-42ca-b927-c737a0d173b5](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/cb3f8064-29c8-42ca-b927-c737a0d173b5), containing **1.0.1 (23)**. Build 15's older submission was removed and replaced.

- This is an intentional, fundamental sound-generation change: independent 48 kHz bands, shared pink-weighted coloring, and complementary Butterworth splits at 200 Hz and 2 kHz. Equal band settings preserve one continuous base spectrum.
- One fixed gain supplies headroom without a limiter or nonlinear processing. The analytic combined bound is 0.7999992 before sample-rate conversion, leaving margin below 0.8 for rounding. The largest measured reconstructed output peak was 0.101081 full scale.
- The five logarithmic levels, saved choices, 3/3/2 default, stereo behavior, and playback lifecycle remain. The new default has a different tone and measures 8.79 dB lower digital RMS than the old favorite; device volume may need adjustment.
- **40 core tests, all 32 integration/UI tests in one run, and 164 new-engine Apple-engine renders pass.** Each paired band also passed **30 accelerated hours**, 5.184 billion frames per channel, and 2,916 Mono/Stereo changes. Four comparisons of the retained legacy path with build 22 are bit-identical.
- Release signing, distribution entitlements, background audio, source/package hashes, and fresh default preferences pass. UI/animation sources and compiled Metal match build 22. Final Release phone and both uploaded store previews were visually inspected.
- What to Test notes are saved, and Personal Testing includes build 23 with one tester. Description, What's New, review notes, and updated phone/tablet screenshots are saved in App Store Connect. Automatic release to all users after approval is selected.
- The public [GitHub repository](https://github.com/niembro64/EverNoise) preserves the complete original sound at **`sound-baseline-build-22`**. [Sound history](SOUND_ENGINE_HISTORY.md) documents the old favorite and safe rollback procedure.
- All 12 support assets are live and verified; 177 unrelated files were preserved. Physical-device listening, battery, Bluetooth, and overnight qualification of the new engine remain unperformed. Installation of build 23 has not been observed.

The US public storefront still showed **free version 1.0** at **15:43:05 UTC November 15**. Approval and public release of 1.0.1 are not yet confirmed.

Details: [design and validation](POWER_COMPLEMENTARY_RELEASE.md), [measurements](complementary-audit-v23.json), [spectrum comparison](complementary-spectrum-v23.png), [package manifest and delivery evidence](build-23-manifest.json).

## Historical glass buttons and new starting balance — version 1.0.1, build 22

**Build 22 is available in TestFlight**, confirmed by Apple at **08:40:00 CST (14:40:00 UTC)** on November 15. Upload succeeded at 08:38:15 CST. The browser access host is unavailable, so the public App Review replacement and portal notes/screenshots remain pending.

- Five buttons return for each Low/Mid/High row. A reflective clear-glass rim identifies the selected dot; Off remains a hollow circle. Touch areas are at least 44 by 56 points.
- New installations use buttons **3 / 3 / 2**, counting Off as first. Existing saved mixes and explicit legacy Brown remain intact.
- All **31 distinct integration/UI tests pass** across the full run and focused visual rerun; both core preference tests pass. The first visual run measured 21 faint native-glass edge pixels against the old 20-pixel count limit. The corrected test bounds affected pixel area and color strength; exact grayscale and stillness remain required for the infinity.
- Five production-engine renders measure the actual overlapping spectrum. The layers are smooth but are not a power-complementary crossover. Filters and engine remain unchanged.
- Final Release phone/tablet layouts, fresh defaults, paused/all-Off grayscale, strict signatures, background mode, and package/source hashes were verified. Nine audio/DSP/lifecycle files, compiled Metal, and icons match build 21. The previous slider remains in source.
- All 12 support assets are live and verified, preserving 177 unrelated files. No new physical-device overnight or battery result is claimed.

The US public storefront still showed **free version 1.0** at **14:32:09 UTC November 15** (08:32 CST). Build 15 is the last portal-confirmed public submission; its current review status has not been refreshed.

Details: [validation](GLASS_BUTTONS_RELEASE.md), [spectrum audit](BAND_OVERLAP_AUDIT.md), [manifest](build-22-manifest.json), [upload](upload-confirmation-v22.json), [TestFlight confirmation](testflight-confirmation-v22.json), [support deployment](support-deployment-v22.json).

## Historical circle stops and glass scale windows — version 1.0.1, build 21

**Build 21 is available in TestFlight**, confirmed by Apple at **23:44:01 CST** (05:44:01 UTC November 15). Upload succeeded at 23:42:32 CST. The public App Review replacement and portal notes/screenshots remain pending browser access; the browser access host was unavailable on this turn's read-only recheck.

- Five visible white circles mark every frequency rail. A clear glass window with an inward downward pointer identifies the selected circle without covering it.
- Native iOS 26 Liquid Glass, an outlined rim, inset endpoints, 56-point touch areas, and smooth settling preserve the app's quiet appearance. Fixed circles stay above the glass effect so they remain crisp.
- Tap a circle or drag the window. The same Off / −18 / −12 / −6 / 0 dB choices, saved preferences, and VoiceOver increments remain.
- All **30 integration/UI tests passed in one run**, including all 15 choices, between-stop snapping, visibility of all circles, clear window interiors, grayscale, persistence, and uninterrupted audio counters.
- Final Release phone/tablet layouts and paused appearance were visually inspected. Signing, distribution entitlements, background mode, default preferences, and package/source hashes pass.
- Audio/DSP/lifecycle files, compiled Metal, infinity icons, typography, and original button components match build 20. No new physical-device overnight or battery result is claimed.
- All 12 support assets are live and verified; 177 unrelated files are preserved.

The US public storefront showed **free version 1.0** at **05:38:33 UTC November 15** (23:38 CST November 14). Build 15 remains the last portal-confirmed public review submission; its current review status has not been refreshed.

Details: [validation](SCALE_WINDOWS_RELEASE.md), [manifest](build-21-manifest.json), [upload](upload-confirmation-v21.json), [TestFlight confirmation](testflight-confirmation-v21.json), [support deployment](support-deployment-v21.json).

## Historical five-stop sliders and Audio picker — version 1.0.1, build 20

**Build 20 is available in TestFlight**, confirmed by Apple at **23:10:56 CST** (05:10:56 UTC November 15). Upload succeeded at 23:09:36 CST. The public App Review replacement and portal notes/screenshots remain pending browser access; the browser access host was unavailable on this turn's read-only recheck.

- Native segmented **Audio: Mono / Stereo**, matching Animations; saved choices and the Stereo default persist.
- Thin Avenir Next Ultra Light Low/Mid/High headings match the title.
- Five-stop native sliders with dark-to-muted-color rails, native iOS 26 ticks/thumbs, and 56-point touch targets. Taps, drags, and VoiceOver choose the same Off / −18 / −12 / −6 / 0 dB levels.
- Original button-picker and intensity-symbol components are retained in `App/BandPicker.swift`.
- All **29 distinct integration/UI tests pass** across the full run and three affected UI reruns after fixing the native slider's initial 34-point touch area. Includes all 15 choices, snapping, persistence, paused grayscale, and uninterrupted render counters.
- Final Release phone/tablet layouts, Audio selection states, and grayscale appearance were visually inspected. Signing, distribution entitlements, background audio, package/source hashes, and default Med checks pass.
- All ten audio/DSP/lifecycle files, the compiled Metal library, and infinity icons match build 19. No new overnight physical-device or battery measurement is claimed.
- All 12 support assets are live and verified, with 177 unrelated files preserved.

The US public storefront still showed **free version 1.0** at **05:05:40 UTC November 15** (23:05 CST November 14). Build 15 remains the last portal-confirmed public review submission; its live review status has not been refreshed.

Details: [validation](NOTCHED_SLIDERS_RELEASE.md), [manifest](build-20-manifest.json), [upload](upload-confirmation-v20.json), [TestFlight confirmation](testflight-confirmation-v20.json), [support deployment](support-deployment-v20.json).

## Historical three animation levels — version 1.0.1, build 19

**Build 19 is available in TestFlight**, confirmed by Apple at **19:54:32 CST** (01:54:32 UTC November 15). Upload succeeded at 19:53:02 CST. The public App Review replacement and portal notes/screenshots remain pending browser access. The dedicated browser host was checked again and is unavailable; the prior idle-Edge coordination question remains unanswered.

- Native segmented **Low / Med / High** animation picker in Settings. Low shows a still infinity on black; Med animates only the infinity; High adds floating background ribbons.
- **Med is the default** for new installations and the old On setting. A saved old Off becomes Low. All three new selections persist across reopening.
- Low stops scheduled visual updates. High/Med changes preserve the infinity clock and smoothly add/remove background ribbons. Reduce Motion and hidden-screen suspension remain.
- **All 26 integration/UI tests passed in one run**, including migration, all three visual modes, persistence, static Low frames, no background ribbons in Med, and continued audio counters without an engine restart.
- Fresh Release phone/tablet installs show the Med default. The Settings picker was visually inspected in all three states. Signing, distribution entitlements, background mode, icons, and source/package hashes pass.
- All ten audio/DSP/lifecycle files and the compiled Metal library are identical to build 18. Its color/spatial/motion audit and the build-14 extended audio audit remain the baselines; no new physical-device battery/overnight result is claimed.
- All 12 support assets are live and verified, with 177 unrelated files preserved.

The US public storefront still showed **free version 1.0** at 01:49:10 UTC on November 15 (19:49 CST November 14). Build 15 was the last confirmed public review submission; its live status has not been refreshed.

Details: [validation](ANIMATION_LEVELS_RELEASE.md), [manifest](build-19-manifest.json), [upload](upload-confirmation-v19.json), [TestFlight confirmation](testflight-confirmation-v19.json), [support deployment](support-deployment-v19.json).

## Historical linear light, Liquid Glass, and Avenir Next — version 1.0.1, build 18

Build 18 contains the full color/glass/typography update plus a continuous mist join found necessary during enlarged iPad QA. **Build 18 is available now in TestFlight**, confirmed by Apple's **23:04:51 UTC (17:04 CST)** email. Upload succeeded at 23:03:32 UTC. The replacement public submission and portal notes/screenshots remain pending an idle Edge window; dedicated browser control was unavailable. No build-17 or build-18 App Review submission is claimed.

- All custom artwork decodes exact sRGB, adds and composites in linear light with independent premultiplied alpha, and encodes the completed opaque scene once for display. Nine production-GPU numeric probes and the iOS display-boundary test pass.
- Native iOS 26 Liquid Glass buttons preserve the 80-point gear, 112-point playback target, and 4-point selection borders. Avenir Next is used throughout, with Dynamic Type. Earlier iOS versions retain a system-material fallback.
- The rear infinity is smoothly darker and more translucent. Build 18 replaces discrete nearest-half selection with a continuous geometric join, retaining independent mist composition away from shared tips.
- The new spatial regression checks 6,252 point pairs: build 17 fails with a 0.131066 discontinuity; build 18 passes at 0.000192. All 3,654 build-18 motion frames and all nine color probes pass.
- The build-18 playback-visual UI test passes; the other build-17 tests cover unchanged code. Final Release phone/tablet screenshots and sampled video show the seam removed. Strict signatures, distribution entitlements, background audio, Metal, infinity icons, and source/package hashes pass.
- All ten audio/DSP/lifecycle sources match build 16. Physical iPhone frame cadence, overnight listening, and battery measurement remain open.
- The existing build-17 support deployment already includes the new appearance and typography. All 12 live assets matched source, preserving 177 unrelated files.

The public US storefront check at 23:03:51 UTC still showed **1.0, free**. Build 15 was the last portal-confirmed App Review submission; its live review state has not been refreshed.

Details: [validation](LINEAR_LIGHT_GLASS_RELEASE.md), [color audit](color-compositing-v18.json), [motion audit](ribbon-motion-v18.json), [build-18 manifest](build-18-manifest.json), [upload](upload-confirmation-v18.json), [TestFlight confirmation](testflight-confirmation-v18.json).

## Historical linear-light preview — version 1.0.1, build 17

Uploaded successfully at **22:51:34 UTC**. Apple's notification at **22:53:01 UTC** confirms **1.0.1 (17) is ready to test**. Installation, saved What to Test notes, and refreshed group status were not observed. All 24 distinct integration/UI tests passed across the final full run and a targeted rerun; source/package evidence is in `build-17-manifest.json`. Final iPad visual QA then found a faint mist seam, corrected in build 18. Build 17 was not submitted for public review.

## Historical larger infinity and floating ribbons — version 1.0.1, build 16

**Build 16 uploaded successfully at 15:56:27 CST. TestFlight availability and App Review submission are not yet confirmed.** The beta notes, listing text, and new phone/tablet screenshots are ready. Edge was in active use; an idle-window coordination question is pending before the portal updates. Build 15 was the last confirmed App Review submission; its current review status has not been refreshed.

The US public storefront was refreshed for this release: **1.0 remains available for free**. See `public-storefront-v16.json` for the timestamped response.

- A much larger infinity fills the upper screen. Four faint closed ribbons float across the entire background with slightly faster motion, gentle turning and depth changes, using the shared material and smooth clock.
- The 22-point gear has an 80-by-80-point touch target. Selected Low/Mid/High borders are 4 points, doubled from 2.
- All 20 distinct integration/UI tests passed across the full run and one targeted rerun. The initial background-only pixel sample overlapped the enlarged infinity; correcting its location resolved the test without application changes or relaxed thresholds.
- The actual production shader passed 2,436 sampled frames, including the four-minute wrap, with visible ribbons in every background third. Final Release phone/tablet layouts, Settings, and recorded motion were visually checked.
- All 14 audio/lifecycle/clock/palette files match build 15 exactly. Strict package signatures, distribution identity, background audio, compiled Metal, and infinity icons passed. Physical iPhone motion and overnight/battery measurements remain unperformed.
- Updated support pages are live; all 12 assets match source and 177 unrelated files were preserved.

Details: [validation](FLOATING_RIBBONS_RELEASE.md), [upload](upload-confirmation-v16.json), [shader measurements](ribbon-motion-v16.json), [manifest](build-16-manifest.json), and [support](support-deployment-v16.json).

The following sections retain historical release observations.

## Historical calmer colors and smoother ribbons — version 1.0.1, build 15

**Build 15 is available in TestFlight and submitted for App Review.** Apple confirmed **1 Item Submitted** for submission `dc0cc5ca-0bea-4a48-8ba4-796aef8c7831`. Automatic release to all users after approval is selected. Approval and public release of 1.0.1 are not yet confirmed.

The US public storefront was refreshed this session: **1.0 remains available for free**. Personal Testing shows **1.0.1 (15), Testing**, one tester, and Saved notes. The last installed beta observed is **1.0.1 (14)**.

- Stereo now defaults on when no preference exists; explicit saved choices persist. Native switches show soft green when enabled and gray when off.
- The title is light and rounded. Muted rose, sage, and periwinkle controls share a balanced six-hue palette with the infinity and background.
- Four enormous, faint loops now render in one fixed viewport, with continuous transforms inside Metal and slower flow/drift. Per-frame SwiftUI texture transforms were removed to address the reported jitter.
- All **20 integration/UI tests passed**. A production-shader audit checked **1,827 frames**, ordinary phases, repeated static inputs, and the four-minute wrap. Background frame changes stayed below one 8-bit step in the sampled sequences.
- All DSP and PlaybackCore sources are byte-identical to build 14. Its extended audio measurements remain the baseline; they were not rerun as new build-15 results. Physical iPhone smoothness, overnight listening, and battery results are not claimed.
- Release phone/tablet layouts, Settings switch states, sampled video, both uploaded Apple device previews, signatures, entitlements, background audio, compiled Metal, infinity icons, source/package hashes, and all 12 live support assets were checked.

Details: [validation](CALMER_VISUALS_RELEASE.md), [shader measurements](ribbon-motion-v15.json), [TestFlight](testflight-confirmation-v15.json), [submission](submission-confirmation-v15.json), and [support](support-deployment-v15.json).

[Build-15 App Review submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/dc0cc5ca-0bea-4a48-8ba4-796aef8c7831)

The following sections retain historical observations. Build 14 reached TestFlight; build 15 completed the public replacement submission.

## Historical larger ribbons and stereo — version 1.0.1, build 14

**Build 14 is available in TestFlight. The App Store replacement submission is in progress.** Personal Testing shows 1.0.1 (14), Testing, one tester, and Saved notes. Build 13's pending review was canceled so it can be replaced with build 14. Final public submission has not yet been confirmed.

Version 1.0 remains public and free; the US storefront was refreshed during this release. The observed installed beta is 1.0.1 (13).

- Four enormous, fainter closed background loops use the shared rainbow material and smooth motion.
- The outline gear opens Settings. Stereo is off by default, remembers its preference, and creates independent left and right noise. Switching fades without restarting playback; changing the setting while paused preserves pause.
- 37 core tests and all 19 final iOS integration/UI tests passed. Actual Apple-engine renders covered all 125 stereo mixes and four output rates, with 199 successful cases and zero retries. Each band's source passed 30 accelerated hours with no silent buffers.
- The original source filters/gains remain. The permanent two-channel path removes the old mono converter's 3.01 dB attenuation at 44.1 kHz; this is documented in TestFlight notes and the conversion audit. Tested 48 kHz mono output is bit-identical. Estimated intersample headroom was 13.63 dB across the audit cases.
- Phone, tablet, Settings, and recorded motion were visually inspected. Signed package, background mode, distribution entitlements, compiled Metal, and infinity icons passed. Physical-device overnight, stereo listening, and battery results are not claimed.
- All 12 support assets are live and verified; 177 unrelated files were preserved.

Details: [build-14 validation](STEREO_RIBBONS_RELEASE.md), [measurements](stereo-measurements-v14.json), [TestFlight confirmation](testflight-confirmation-v14.json), and [support deployment](support-deployment-v14.json).

The sections below preserve historical observations; build 13's queued review has been canceled for replacement.

## Rainbow ribbons — version 1.0.1, build 13

**Version 1.0 remains public and free on the [App Store](https://apps.apple.com/us/app/evernoise/id6834413344).** The US storefront was checked this session and returned EverNoise, version 1.0, price 0.00.

**Build 13 is available in TestFlight and Waiting for Review for public release.** Apple confirmed **1 Item Submitted** at 2:08 PM CST on November 14, 2026. Automatic release to all users after approval is selected. This replaces the canceled build-12 submission.

- Six color-wheel currents accompany the mixed-color infinity. The bands' logarithmic power weights their proportions, with a baseline amount of every hue.
- Two much larger, fainter closed loops slowly drift and bend behind the top of the screen. The deeper loop is larger, fainter, and slower. Every ribbon shares one liquid shader, palette, and smooth clock.
- The info sheet's **Animations** switch persists across relaunch. Off leaves a still infinity and plain black background, disables custom fades, and stops scheduled visual updates. Sound continues. Paused/all-off visuals settle into grayscale; hidden screens and Reduce Motion are respected.
- All **15 final tests passed**: five real-engine, seven motion/palette, and three UI tests. Pixel checks verified all six hue families, foreground/background motion, grayscale pause, and exact stillness with animations off. Preference persistence and continued audio without a restart passed.
- Release iPhone/iPad layouts, settings, recorded motion, and both actual uploaded Apple device previews were visually checked. All ten audio/lifecycle sources match build 12 exactly. Final source and signed-package hashes match the manifest; distribution identity, signature, background mode, entitlements, Metal library, and icons passed.
- Personal Testing shows **1.0.1 (13), Testing**, one tester, and Saved notes. The last installed build observed was **1.0.1 (12)**; build-13 installation/listening has not been observed. No physical-device overnight, frame-rate, thermal, or battery measurement is claimed.
- Updated support pages are live: all 12 assets match source and 177 unrelated files were preserved. Build-12 evidence and screenshots remain separately backed up; its historical submission record now notes the cancellation.

Details: [build-13 validation](SPECTRAL_RIBBONS_RELEASE.md), [submission confirmation](submission-confirmation-v13.json), [TestFlight confirmation](testflight-confirmation-v13.json), and [support deployment](support-deployment-v13.json).

[Build-13 App Review submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/adc6953d-f45c-4c22-99b5-5dc273e805eb)

The sections below preserve historical observations. Build 12's pending review was canceled and replaced by build 13. Build 11 is the approved public release.

## Historical living infinity — version 1.0.1, build 12

**Version 1.0 is public and free on the [App Store](https://apps.apple.com/us/app/evernoise/id6834413344).** Apple approved build 11 during this update; App Store Connect shows Ready for Distribution and the US storefront lookup returned EverNoise, version 1.0, price 0.00.

**The new animation is available now in TestFlight as 1.0.1 (12), and Waiting for Review for public release.** Apple confirmed **1 Item Submitted** at 1:34 PM CST on November 14, 2026. Automatic release to all users after approval is selected.

- Larger liquid infinity with luminous internal currents, a soft membrane, nearby mist, and an over/under crossing.
- Continuous position, velocity, and acceleration when motion targets change; gradual color blends and smooth play/pause transitions. Motion settles to still grayscale when paused/all-off, suspends when hidden, and respects Reduce Motion.
- All 12 final tests passed: five real-engine, five motion, and two UI tests. Actual screenshots confirm playing motion, paused stillness, and grayscale. Release phone/tablet layouts and uploaded Apple previews were visually checked.
- All ten audio/lifecycle sources match build 11. Strict signature, package identity, background audio, entitlements, Metal library, icons, source hashes, and package hash passed. No physical-device overnight or performance result is claimed.
- Personal Testing shows **1.0.1 (12), Testing**, one tester, and Saved notes. The last installed build observed was **1.0 (11)**.
- Updated support pages are live, with all 12 assets verified and 177 unrelated files preserved. Build-11 release records and screenshots have separate backups.

Details: [build-12 validation](LIQUID_INFINITY_RELEASE.md), [submission confirmation](submission-confirmation.json), [TestFlight confirmation](testflight-confirmation.json), and [support deployment](support-deployment.json).

[Build-12 App Review submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/f4272b81-521b-49e6-a3f2-acc4d74754eb)

The sections below preserve historical observations from earlier builds. Build 11 was subsequently approved and released; its latest evidence is in `submission-confirmation-v11.json`.

## Historical flowing infinity and quieter symbols — build 11

**Version 1.0 (11) is available in internal TestFlight and Waiting for Review.**
Apple confirmed **1 Item Submitted** at 11:56 AM CST on November 14 for
submission `aa343ed8-c3b4-43ef-810c-1528f91d1d9b`. It replaces the canceled build-10
submission. Automatic free release is selected; public availability awaits Apple.

- Small hollow circle for Off; one growing dot for each active intensity.
  Removed selection checkmarks; the border indicates the selection.
- Paused/all-off controls are grayscale. A gentle mist flows around the infinity
  while sound plays. The animation is disabled while hidden or Reduce Motion is on.
- Five engine tests and two UI tests passed, including screenshot-pixel checks
  for motion, paused stillness, and grayscale. Background audio continued without
  restarting the engine. All ten audio/lifecycle sources match build 10.
- Release iPhone/iPad layouts and actual Apple screenshot previews were checked.
  Signing, version, background audio, distribution entitlements, and final source
  and IPA hashes passed. No new physical-device overnight run is claimed.
- TestFlight notes Saved; Personal Testing shows **1.0 (11), Testing**, one tester.
  The last installed version observed was **1.0 (10)**.
- Updated support instructions are live; all 12 assets match and 177 unrelated
  files were preserved. Build-10 records and screenshots have -v10 backups.

Details: [build-11 validation](FLOW_VISUALS_RELEASE.md),
[submission confirmation](submission-confirmation.json),
[TestFlight confirmation](testflight-confirmation.json), and
[support deployment](support-deployment.json).

[Current App Store submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/aa343ed8-c3b4-43ef-810c-1528f91d1d9b)

## Historical minimal interface — build 10

**Version 1.0 (10) is available in internal TestFlight and Waiting for Review.**
Apple confirmed **1 Item Submitted** at 11:00 AM CST for submission
`b370bd9e-499d-4dc5-b7f5-8895e1a529f5`. It replaces the canceled build-9
submission. Automatic free release remains selected; public availability is
pending Apple approval.

- Removed the volume slider, numeric mix summary, routine status text, footer
  slogan, and privacy/support text link. The normal main screen keeps only
  EverNoise, Your sound. All night., and Low/Mid/High labels.
- Increased title/subtitle/row type, enlarged play/pause to 112 points, and
  replaced Off/1/2/3/4 text with a slashed circle and rising intensity bars.
  Outline/checkmark selection and explicit VoiceOver labels are retained.
  Privacy/help opens through the info icon; audio failures can still explain
  themselves when relevant.
- Five actual iOS-engine tests passed. The initial UI run caught an accessibility
  labeling issue; it was corrected and the full UI/lifecycle flow passed.
  Both Release simulator layouts and both actual Apple screenshot previews
  were visually inspected. Archive, export, upload, strict signature,
  background-audio, and entitlement checks passed.
- All ten audio/lifecycle source files are unchanged from build 9. Source,
  signed IPA, metadata, and screenshot hashes match the final release records.
  No new physical-device listening or overnight test is claimed.
- TestFlight notes Saved; Personal Testing shows **1.0 (10), Testing**, one
  tester. The last installed version observed was **1.0 (9)**.
- Support instructions are live at all three URL aliases. All 12 live assets
  match source; all 177 unrelated portfolio files were preserved.

Details: [build-10 validation](MINIMAL_UI_RELEASE.md),
[submission confirmation](submission-confirmation.json),
[TestFlight confirmation](testflight-confirmation.json), and
[support deployment](support-deployment.json).

[Build-10 App Store submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/b370bd9e-499d-4dc5-b7f5-8895e1a529f5)

The following sections preserve historical release observations.

## Historical final naming — build 9

**Version 1.0 (9) is available in internal TestFlight and Waiting for Review.**
The final name is **EverNoise**. The public App Store release is pending Apple
approval; automatic free release is selected. Apple confirmed **1 Item Submitted**
on November 14 at 10:32 AM CST, for submission
`4d42cb7a-c43d-40d6-8140-974b9be23b46`.

- Renamed the installed app, main screen, Now Playing, privacy text, store
  listing, screenshots, TestFlight notes, and support/privacy site.
- Confirmed the RGB infinity icon in the signed iPhone/iPad package and in
  Apple's actual included-icon preview. Both uploaded store screenshots were
  visually inspected and show EverNoise with the three band pickers.
- Build 9 Release simulator/device builds, signing, upload, identity, background
  audio, and entitlements passed. Production sources and the signed IPA match
  `build-9-manifest.json` after submission. Audio implementation is unchanged
  from builds 7 and 8. Build 8's five engine tests and full UI flow passed;
  tests were not rerun for build 9's name-only change. Build 9 layouts were
  checked on both iPhone and iPad simulators.
- TestFlight's Personal Testing group shows **1.0 (9), Testing**, with the
  existing tester and saved notes. Last installed version observed: **1.0 (8)**.
- The support site is live at `https://niemo.io/evernoise/`; both old URL paths
  still work. All 12 live assets match source. All 177 unrelated site files
  were preserved in the verified atomic release.
- The short-lived Endless Noise build-8 submission was canceled and replaced
  by this final-name build. Build-8 and earlier evidence is retained separately.
- Physical listening and overnight playback of build 9 remain unverified.
  The pause control and playback behavior remain as previously implemented.

Details: [build-9 release validation](EVERNOISE_RELEASE.md),
[submission confirmation](submission-confirmation-v9.json),
[TestFlight confirmation](testflight-confirmation-v9.json), and
[support deployment](support-deployment-v9.json).

[Historical build-9 submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/4d42cb7a-c43d-40d6-8140-974b9be23b46)

The sections below preserve historical observations, including then-current
names and review states. The build-13 section above is the current release state.

## Historical Endless Noise — build 8

Build 8 was submitted at 10:19 AM CST, reached Waiting for Review, and became
available in Personal Testing. The tester installed it. The user then selected
EverNoise; the build-8 submission was canceled and replaced by build 9.
See [build-8 validation](ENDLESS_NOISE_RELEASE.md),
[submission snapshot](submission-confirmation-v8.json), and
[TestFlight snapshot](testflight-confirmation-v8.json).

## Historical three-band pickers — build 7

**Version 1.0 (7) is available in internal TestFlight.**
The Personal Testing group shows **Testing** and the build notes were saved.
The installed app uses the working name **Persistent Noise** and a new RGB
infinity logo. The public App Store listing is still **Just Brown Noise**, with
build 6 **Waiting for Review**, reconfirmed in the live portal this session.
Build 7 has not replaced that submission. Final public naming and the possible
removal of the in-app pause control are pending the user's next decision.

- Replaces the grid with separate Low, Mid, and High pickers, each offering
  Off / -18 / -12 / -6 / 0 dB. RGB buttons vary with intensity, and a small
  infinity mark combines the sound's color on a pure-black screen.
- Existing preferences migrate with Low 4, preserving all 25 old sounds.
  All 125 new combinations persist, including a saved Low 0. All three Off
  intentionally produces silence. Smooth fades and source clocks are preserved.
- 29 core tests, five iOS-engine integration tests, and the UI flow passed.
  All 135 Apple-engine renders passed; maximum estimated intersample peak was
  -13.29 dBFS. All 25 old balances match build 6 sample-for-sample. See
  [the picker audit](BAND_PICKERS_AUDIT.md) and [measurements](band-measurements.json).
- Release iPhone/iPad layouts and the new icon were visually inspected.
  Preview images are under `previews/build-7/`. Submitted store screenshots,
  listing text, support site, and pricing have not been changed for this beta.
- Archive and cloud-signed export passed. Strict signature, display name,
  bundle/version, background audio, and entitlement checks passed.
  Package: `build/AppStore-v7/JustBrownNoise.ipa`.
  Source and asset hashes: [build-7-manifest.json](build-7-manifest.json).
- Upload completed November 14 at 08:38:48 CST (14:38:48 UTC). The Personal
  Testing group shows **1.0 (7), Testing** for the existing tester. The last
  installed build observed was **1.0 (6)**. Evidence:
  [testflight-confirmation-v7.json](testflight-confirmation-v7.json). The previous
  build-6 snapshot is retained in `testflight-confirmation-v6.json`.
- Physical listening and overnight testing of build 7 remain unverified.

## Historical logarithmic levels — build 6

**Version 1.0 (6) is available in internal TestFlight and Waiting for Review.**
The Personal Testing group shows **Testing**. Apple confirmed **1 Item Submitted**
for submission `665b23fd-74b3-435f-af4b-e7fc00b5c7a4` on November 14, 2026.
This replaces the canceled build-5 submission. Automatic free release after
approval remains selected; public availability is pending Apple review.

- Mid/high levels now use **off, -18, -12, -6, and 0 dB** relative to each
  layer's maximum. Active positions are equally spaced by 6 dB. Startup and
  live changes share the same lookup; the 600 ms fades remain continuous.
- Bass, maximum gains, filters, source clocks, saved coordinates, UI, and
  background playback are unchanged. All four corner sounds match build 5
  sample-for-sample at 44.1 and 48 kHz.
- 29 core tests, five actual iOS-engine integration tests, and the UI test passed.
  Emitted layer power matches the requested decibel levels at startup and
  after live changes. All 34 Apple-engine renders passed with no silent buffers
  or render retries; maximum estimated intersample peak was -13.10 dBFS.
  See [the logarithmic-scale audit](LOG_SCALE_AUDIT.md).
- Archive, cloud-signed export, and upload succeeded. Upload completed November
  14 at 02:39:58 CST (08:39:58 UTC). Strict signature, bundle/version, background
  audio, and entitlement checks passed. Final source/package hashes still match
  [build-6-manifest.json](build-6-manifest.json) after submission.
- TestFlight notes were saved and **1.0 (6), Testing** verified. The tester's
  last installed build observed was **1.0 (5)**. Evidence:
  [testflight-confirmation-v6.json](testflight-confirmation-v6.json).
- Build 6 and updated review notes were saved and submitted. Listing text,
  screenshots, support site, and free pricing remain as before. Evidence:
  [submission-confirmation-v6.json](submission-confirmation-v6.json). Historical build-5
  submission and TestFlight snapshots are retained as `-v5.json`.
- Device listening to the new scale and physical overnight playback remain
  unverified. Earlier 48-hour accelerated tests cover the unchanged filters;
  those endurance runs were not repeated for this gain-table correction.

[Historical build-6 submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/665b23fd-74b3-435f-af4b-e7fc00b5c7a4)

The sections below are historical release records.

## Historical build-5 sound grid

**Version 1.0 (5) is available in internal TestFlight and Waiting for Review.**
The Personal Testing group shows **Testing**. Apple confirmed **1 Item Submitted**
for submission `1cb06b38-f3c6-4e83-b523-da124a183edc` by November 14 at 01:13 UTC
(November 13 at 19:13 CST). This replaces the withdrawn build-4 submission.
Automatic free release after approval remains selected. Apple approval and
public App Store availability are pending.

- Replaced White/Brown/Gray with a 5-by-5 grid. Right adds highs, up adds mids,
  and every cell uses the same Brown layer at the same gain. Red stays fixed;
  green follows mids and blue follows highs. Selection is saved, accessible,
  and indicated with a checkmark.
- The bottom-left cell preserves the user-approved Brown output exactly.
  Selection changes fade over 600 ms without restarting the graph or changing
  the Brown source gain. The new midrange layer uses linear filtering and fixed
  gain, without limiting, compression, or automatic normalization.
- 29 core tests, five actual iOS-engine integration tests, and the UI flow
  passed. All 25 cells were exercised while the engine kept running. The UI
  flow also checks background continuity, pause behavior, and saved selection.
- Thirty-four Apple-engine offline renders passed spectrum, transition,
  silence, and headroom checks. Measured 20–200 Hz variation across the grid was
  0.000011 dB. Maximum estimated intersample peak was -13.10 dBFS in these renders.
  The new midrange source passed 48 accelerated hours. See
  [the sound-grid audit](SOUND_GRID_AUDIT.md) for methods, bounds, and limitations.
- Archive, export, and upload succeeded. Upload completed November 13 at
  19:03:04 CST (November 14 at 01:03:04 UTC). Strict signature, version, bundle,
  background audio, and entitlement checks passed.
- Signed package: `build/AppStore-v5/JustBrownNoise.ipa`.
  Source/package hashes: [build-5-manifest.json](build-5-manifest.json).
  Final source and package hashes were checked again after submission and match.
- Store subtitle, description, keywords, promotional text, review notes, and
  iPhone/iPad screenshots were updated. Both uploaded screenshot previews were
  visually inspected in App Store Connect and show the grid. Build 5 was the
  selected review build and appeared as **1.0 (5)** in the final submission.
- TestFlight notes were saved. The group shows **1.0 (5), Testing**; the tester's
  last installed version observed was **1.0 (4)**. Evidence:
  [testflight-confirmation-v5.json](testflight-confirmation-v5.json).
- Submission evidence: [submission-confirmation-v5.json](submission-confirmation-v5.json).
  Build-4 submission, TestFlight, and support snapshots are preserved in the
  corresponding `-v4.json` files.
- Support page updated at `https://niemo.io/just-brown-noise/`. All 180 files in
  the new public release were verified; only the app support index changed.
  The live page matches the new source after Cloudflare email decoding.
- The user confirmed the original Brown sounds smooth on the iPhone speaker.
  Physical listening to the new grid, overnight playback, battery, Bluetooth,
  and all OS interruption combinations remain unverified.

[Historical build-5 submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/1cb06b38-f3c6-4e83-b523-da124a183edc)

## Historical build-4 three sounds

**Version 1.0 (4) is available in internal TestFlight and submitted to App Review.**
The Personal Testing group shows **Testing**. Apple confirmed **1 Item Submitted**
for submission `2bccb727-4f0d-4f96-82a3-a8ae7921c7c0`. This replaces the withdrawn build-3 submission.
Automatic free release after approval remains selected. Apple approval and
public App Store availability are pending.

- Added White, Brown, and warm Gray with a persistent selection and smooth
  600 ms transitions. The approved Brown output is unchanged sample-for-sample.
- The user confirmed that build 3's Brown sounds smooth and consistent on the
  iPhone speaker. The portal now shows build 3 installed on an iPhone 16 Pro Max.
  Listening confirmation for the new White/Gray sounds is pending.
- 25 core tests, five real-engine integration tests, and one simulator UI flow
  passed. Each production source passed 48 accelerated hours; twelve actual
  Apple-engine renders passed spectrum, silence, and headroom checks.
  See [the new sound audit](NOISE_OPTIONS_AUDIT.md).
- Archive, export, and upload succeeded. Upload completed November 13 at
  18:26:17 CST (November 14 at 00:26:17 UTC). Strict signature, version, bundle,
  background audio, and entitlement checks passed.
- Signed package: `build/AppStore-v4/JustBrownNoise.ipa`.
  Source/package hashes: [build-4-manifest.json](build-4-manifest.json).
  Final source hashes were checked again after submission and still match.
- Store subtitle, description, keywords, promotional text, review notes, and
  iPhone/iPad screenshots were updated. Both uploaded screenshots were visually
  inspected in App Store Connect. Build 4 is the selected review build.
- TestFlight notes were saved, and the internal group shows **1.0 (4), Testing**.
  TestFlight evidence: [testflight-confirmation-v4.json](testflight-confirmation-v4.json).
- Submission evidence: [submission-confirmation-v4.json](submission-confirmation-v4.json).
  Earlier build-3 evidence is preserved in the corresponding `-v3.json` files.
- Support page updated at `https://niemo.io/just-brown-noise/`. All 180 files in
  the new public release were verified; only the app support index changed.
  The live page matches the new source after Cloudflare email decoding.
- Physical overnight playback, battery, Bluetooth, and all OS interruption
  combinations remain unverified. Gray is a warm spectral approximation,
  not a calibrated inverse hearing curve.

[Historical build-4 submission](https://appstoreconnect.apple.com/apps/6834413344/distribution/reviewsubmissions/details/2bccb727-4f0d-4f96-82a3-a8ae7921c7c0)

## Historical build-3 audio correction

Build 1 was withdrawn from App Store review to replace the reported distorted
audio. Version 1.0 (build 2) is available in the internal Personal Testing group
with the revised linear generator. Build 3 adds final scene/remote-control fixes
and uploaded successfully at **2026-11-13 14:16:51 UTC**.

**Version 1.0 (3) is available in TestFlight and submitted to App Review.**
The Personal Testing group shows **Testing**. Apple confirmed **1 Item Submitted**
for the replacement submission `36535c32-2ef6-418f-88bc-cbee8f901f0c`.
Automatic free release after approval remains selected; Apple approval and
public App Store availability are still pending. Current evidence is in
`testflight-confirmation.json` and `submission-confirmation.json`.

- 20 core tests, three iOS real-engine integration tests, and the UI test passed.
- 48 accelerated hours of the production generator passed without clipping or
  silent buffers; see [the complete audio audit](AUDIO_AUDIT.md).
- Apple conversion checks passed at 16, 44.1, and 48 kHz, with estimated
  intersample peaks and channel/boundary checks.
- Final simulator results: `build/release-v3/FinalIntegrationAndUI.xcresult`.
- Final signed package: `build/AppStore-v3-final/JustBrownNoise.ipa`.
  Strict code-signature verification and version/background-mode checks passed.
- Package and source hashes: [build-3-manifest.json](build-3-manifest.json).
- Final archive/export/upload logs: `build/release-v3/`.
- Free pricing across 175 regions was reconfirmed in the live portal.
- TestFlight now reports build 1 installed on the user's iPhone 16 Pro Max,
  iOS 26.6.2. Installation/listening confirmation for revised builds is pending.
- Physical overnight playback remains unverified. Accelerated DSP and simulator
  results do not qualify phone speakers, Bluetooth, battery, or every OS event.

The records below describe the earlier build-1 release and are historical.
Its original submission/tester snapshots are preserved as
`submission-confirmation-v1.json` and `testflight-confirmation-v1.json`.

## Historical build-1 release

Implemented native iPhone/iPad app, version 1.0 (build 1), bundle identifier
`io.niemo.JustBrownNoise`, developer team `82F3X3VDHP`.

**Historical status: build 1 was submitted and Waiting for Review.**
Confirmed in App Store Connect on November 13, 2026, by 13:33 UTC (7:33 AM CST).
Automatic free release is configured after approval. Apple approval and public
App Store availability remain pending.

[App Store Connect](https://appstoreconnect.apple.com/apps/6834413344/distribution/ios/version/inflight)

### Original TestFlight setup

- Version 1.0 (1) is **Ready to Test** in the internal **Personal Testing** group.
- `niemeyer.eric@gmail.com` was added; Apple shows **Invited**.
- Automatic distribution is enabled for future uploaded builds in this group.
- Confirmed by 2026-11-13 13:40 UTC. The user can accept Apple’s TestFlight
  invitation on their iPhone and install the app while App Store review is pending.
- Installation and real-device testing have not yet been observed.
  Evidence: `testflight-confirmation.json`.

### Original validation

- 12 Swift Testing tests in two suites (including four sample-rate cases).
- Simulator UI test on iOS 26.2 / iPhone 17 Pro: auto-start, pause/resume,
  backgrounding, and foregrounding. Rendered-frame counts advanced during the
  background interval and the engine start count did not change.
- Accelerated 30-hour production-renderer test: 5,184,000,000 samples across
  1,265,625 buffers. Every sample was finite and bounded; no silent buffers.
  RMS 0.143613, mean 0.00000020, peak 0.523060, maximum boundary step 0.026475.
- Spectrum check: -5.97 dB/octave across 125–4,000 Hz.
- Release simulator build and unsigned arm64 iOS release archive.
- iPhone and iPad App Store screenshots captured from the release app and
  visually inspected. Uploaded JPG files (no alpha): 1206×2622 for the required
  medium iPhone display and 2064×2752 for iPad. A 1320×2868 large-iPhone
  screenshot is also available locally.
- Support/privacy pages published to `https://niemo.io/just-brown-noise/` and
  `/just-brown-noise/privacy.html`. Existing portfolio files retained exactly;
  public-site privacy validation passed. Deployment evidence is in
  `support-deployment.json`.

Logs and Xcode results are under `build/`. The successful UI test result bundle
is `build/SmokeTests-v2.xcresult`.

### Original distribution and submission

- The updated developer agreement block is cleared (verified in the live portal).
- App Store Connect record created: **Just Brown Noise**, Apple ID `6834413344`.
- Distribution export succeeded using cloud-managed Apple Distribution signing
  and the matching App Store provisioning profile. No development device is
  required for this export.
- Signed package: `build/AppStore/JustBrownNoise.ipa`; strict signature
  verification passed, with `get-task-allow = false`.
- Build 1 (version 1.0) successfully uploaded at 2026-11-13 13:22:52 UTC.
  Xcode confirmed “Uploaded package is processing” and “Upload succeeded.”
  Evidence: `build/upload-appstore.log`.
- Store metadata, iPhone/iPad screenshots, support/privacy URLs, 4+ age rating,
  Utilities category, original-content declaration, and review contact are saved.
- Privacy responses published: Data Not Collected.
- Free pricing ($0.00 base and zero-priced regional equivalents) configured.
  Availability set to all 175 countries/regions. Mac and Vision Pro availability
  disabled for this iPhone/iPad release.
- Processed build `de6c534d-58e5-4a5c-a857-e47d6ede9734` attached to version 1.0.
- Apple submission validation passed and version 1.0 (1) was submitted.
  The portal confirmed **“1 Item Submitted”** and **“1.0 Waiting for Review.”**
- Automatic release after approval selected. Apple reports review can take up
  to 48 hours; this is a portal estimate, not a guaranteed review deadline.
- Review approval and public availability have not yet occurred.
  Submission evidence is summarized in `submission-confirmation.json`.

Reproduce the signed export:

```sh
xcodebuild -exportArchive \
  -archivePath build/JustBrownNoise-unsigned.xcarchive \
  -exportOptionsPlist Store/ExportOptions.plist \
  -exportPath build/AppStore -allowProvisioningUpdates
```

The input archive is unsigned; Xcode signs the distribution package during
export. Set destination to `upload` in a separate export-options plist to upload
through the authenticated Xcode account.

Physical-device overnight, lock-screen, battery, Bluetooth, call/Siri, and
media-services-reset testing remain unperformed. The 30-hour result is an
accelerated DSP test, not an overnight device test. No iPhone was available for
installation in `devicectl` during this run.
