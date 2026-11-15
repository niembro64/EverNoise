# Endless Noise — build 8

Historical build: the user initially selected **Endless Noise**, then changed
the final name to **EverNoise**. Build 8 was submitted and reached Waiting for
Review, then canceled and replaced by build 9. See `EVERNOISE_RELEASE.md`.

## Changes and validation

- Renamed the installed app, main screen, Now Playing title, and privacy text.
  The app keeps its existing bundle identifier and saved sound settings.
- The RGB infinity icon is in the production asset catalog and signed iOS
  package. The decoded packaged iPhone icon was visually inspected; build 8's
  packaged icon exactly matches that verified image. Both iPhone and iPad
  `CFBundlePrimaryIcon` entries select this catalog. App Store Connect's actual
  build-8 icon preview was also opened and visually confirmed as the infinity
  symbol on black.
- Five actual iOS-engine integration tests and the full picker/lifecycle UI
  test passed. Release simulator and device archive builds, cloud-signed export,
  strict signature, version, background-audio, and entitlement checks passed.
- Production DSP, filters, noise mix, audio driver, and playback controller
  hashes match build 7. Its 125-mix / 135-render measurements remain applicable;
  no signal changes were made. Physical build-8 listening and overnight playback
  remain unverified.
- Release iPhone and iPad screens were captured and inspected. Updated store
  JPGs were uploaded and their actual Apple previews were visually inspected.
- The pause button remains, consistent with the previous discussion. No new
  playback behavior was inferred from this naming/icon request.

Evidence: `build-8-manifest.json`, `build/release-v8/IntegrationAndUI.xcresult`,
`build/release-v8/tests.log`, and the archive/export/upload logs in that directory.

## Store and support

The initial live check showed build 6 **Waiting for Review**: the app was not
publicly released. Build 6 still had the old icon and grid. After preparing and
validating build 8, its pending submission was canceled for replacement.

Apple accepted and saved **Endless Noise** and the new subtitle. The description,
keywords, promotional text, support URL, review notes, and iPhone/iPad screenshots
were updated for the three independent band pickers. Build 8 was attached, and
automatic release after approval was selected. Submission and TestFlight
evidence is retained in `submission-confirmation-v8.json` and
`testflight-confirmation-v8.json`; the tester installed build 8.

The support and privacy pages are live at `https://niemo.io/endless-noise/`.
Existing `just-brown-noise` URLs serve the updated content too. All eight live
assets match source after decoding Cloudflare's email obfuscation. A new atomic
public release preserved all 177 unrelated portfolio files. See
`support-deployment-v8.json` for hashes and rollback location. Build 9 now
serves EverNoise content at these same legacy URLs.
