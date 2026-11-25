# EverNoise — quieter symbols and flowing infinity, build 11

Historical validation record. Apple approved build 11 and version 1.0 became publicly listed on November 14, 2026. See `submission-confirmation-v11.json`; the current update is described in `LIQUID_INFINITY_RELEASE.md`.

Build 11 was signed and uploaded on November 14, 2026 at 17:50:27 UTC.
Portal submission and TestFlight availability are recorded separately below.

## Changes

- Replaced rising bars with one filled dot per active level, sized 6, 10, 14,
  and 18 points. Off is an 8-point hollow circle without a slash. Selection
  uses only the border. VoiceOver still announces each band and intensity.
- Controls and infinity are grayscale when paused, interrupted, unavailable,
  or all three bands are off. RGB colors remain while audible playback is active.
- A slow mist flows along the infinity ribbon during playback. Two softly
  tapered streams follow the curve over a 12-second circuit, with subtle
  transverse movement and no flashing. The canvas is 96 by 48 points.
- The animation is display-only: no access to audio samples or engine controls.
  Its TimelineView runs at no more than 30 updates per second and is removed
  when the app is not active, the help sheet is open, sound is paused/all-off,
  or Reduce Motion is enabled. The audio lifecycle is unchanged.
- Help, store description, review notes, TestFlight notes, and support site
  now describe the dots, selection border, grayscale pause, and motion behavior.

## Validation

Five real iOS-engine integration tests and two UI tests passed in
`build/release-v11/IntegrationAndUI.xcresult`. The lifecycle UI test verifies
pause/resume, every level in all three bands, all-off, independent choices,
persistence, and 15 seconds of background rendering without an engine restart.

The new visual test inspects actual screenshot pixels: color is present while
playing, the infinity changes between frames, paused controls have no colored
pixels, the paused mark is identical between frames, and all-off is grayscale.
The phone's paused and playing layouts and iPad Release layout were visually
inspected. A 12-second iPad video and six-frame contact sheet show the flowing
mist; artifacts are under `build/release-v11/`. The initial build hit a Swift
compiler type-check timeout in a large Canvas closure; extracting the drawing
function fixed it before the passing builds and tests.

All ten audio/lifecycle sources match build 10 exactly. Release simulator and
device builds, archive, cloud-signed export, strict signature, version/bundle
identity, background-audio mode, and distribution entitlements passed. Packaged
infinity icons match build 10. The manifest includes the new InfinityVisual file
and all previous production files (24 total). No physical-device listening,
overnight run, or battery measurement is claimed for this visual update.

Package: `build/AppStore-v11/JustBrownNoise.ipa`.
SHA-256: `5452ed29ee43107e59f5bf3d63b69151e5abad0f6e392cdc0beadd29d4769af2`.
See `build-11-manifest.json` for hashes and verification results.

## Support deployment

All 12 live assets match source across /evernoise/, /endless-noise/, and
/just-brown-noise/ after Cloudflare email decoding. The atomic release preserves
all 177 unrelated portfolio assets. `support-deployment.json` records the new
release and previous release for rollback. Build-10 metadata, notes, screenshots,
and portal records were preserved with the -v10 suffix.

## Publishing

Apple confirmed **1 Item Submitted** for **1.0 (11)** at 11:56 AM CST on
November 14. Submission `aa343ed8-c3b4-43ef-810c-1528f91d1d9b` is **Waiting for
Review**, replacing build 10. Both actual Apple screenshot previews were
visually inspected. Automatic free release after approval remains selected;
the app is not yet public. See `submission-confirmation.json`.

TestFlight notes showed **Saved**, and the Personal Testing group showed
**1.0 (11), Testing**, with one tester. The last installed build observed was
**1.0 (10)**. See `testflight-confirmation.json`. Source, test, and signed-package
hashes were verified again after submission and match the final manifest.
