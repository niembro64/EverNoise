# EverNoise — minimal interface, build 10

Build 10 was signed and uploaded successfully on November 14, 2026 at
16:50:13 UTC (10:50:13 AM CST). It is available in internal TestFlight and
Waiting for Review for the App Store, replacing build 9.

## Changes

- Removed the system-volume slider. Physical device volume buttons still work.
- Enlarged the play/pause target from 48 to 112 points and its symbol from 17
  to 40 points. Title increases from 32 to 44 points, subtitle from footnote
  to title3, and row labels from subheadline to title2; text uses Dynamic Type.
- The normal main screen's only visible text is EverNoise, Your sound. All
  night., Low, Mid, and High. Removed the numeric mix summary, routine playback
  status, extra footer slogan, and text link for privacy/support.
- A slashed circle means Off. Four rising bars show one through four active
  intensity steps. Selected buttons retain their outline and checkmark.
  Explicit VoiceOver labels announce the band and level; the play/pause
  control's accessibility value includes playback status. An actual audio
  failure can still show its explanatory message.
- Privacy and support are available from the top-right info icon. In-app help,
  local store description/review notes, TestFlight notes, and the support site
  explain the symbols and physical volume buttons.
- The background, combined-color infinity, five logarithmic levels, saved
  settings, and sound/playback implementation are preserved.

## Validation

Five actual iOS-engine integration tests passed. The first UI run caught missing
accessibility identifiers/labels caused by hiding the new symbol view. Removing
that hiding and redundant accessibility regrouping corrected the issue. The
complete UI flow then passed: pause/resume, 15 seconds backgrounded without
restarting the engine, every band level, independent selections, all-off,
persistence including Low Off, large play/pause target, absent slider/summary,
and opening/dismissing the info sheet.

Results: `build/release-v10/IntegrationAndUI.xcresult` (five engine tests passed,
initial UI issue) and `build/release-v10/UI.xcresult` (corrected UI flow passed).
Release iPhone and iPad screens were captured and visually inspected. A largest
Dynamic Type top-of-screen capture is retained separately; normal screenshots
are the ones prepared for the store. No physical-device listening or overnight
test was performed for this UI-only release.

Release simulator build, iOS archive, cloud-signed export, strict code signature,
identity/version, background-audio mode, and distribution entitlements passed.
All ten audio/lifecycle source files match build 9. Packaged iPhone/iPad infinity
icons match its verified images. Only ContentView, PrivacyView, the build number,
and the generated project changed in the 23-file production manifest.

Package: `build/AppStore-v10/JustBrownNoise.ipa`.
SHA-256: `87634a90b966d41416755f7e00c98fdffed056aac216e875cfdba477c2e1b922`.
See `build-10-manifest.json` and logs under `build/release-v10/`.

## Support deployment

The new help is live at `https://niemo.io/evernoise/` and both legacy paths.
All 12 live assets match source after Cloudflare email decoding. The atomic
release has 189 verified files and preserves 177 unrelated files; details and
rollback location are in `support-deployment.json`.

## Publishing status

Apple confirmed **1 Item Submitted** for **1.0 (10)** at 11:00 AM CST on
November 14. Submission `b370bd9e-499d-4dc5-b7f5-8895e1a529f5` is **Waiting for
Review**. The canceled build-9 submission showed Developer Rejected. Automatic
free release after approval remains unchanged; the app is not public yet.

The description and review notes were saved, build 10 attached, and both
screenshots uploaded. Actual Apple previews were visually inspected and show
the new minimal interface. See `submission-confirmation.json` for final metadata
and screenshot hashes. Production source and signed-package hashes were checked
again after submission and match the manifest.

TestFlight notes showed **Saved**. Personal Testing shows **1.0 (10), Testing**,
with one tester. The tester's last installed version observed was **1.0 (9)**.
See `testflight-confirmation.json`. Prior build-9 evidence is preserved with the
`-v9` suffix, including screenshots, metadata, notes, and portal confirmations.
