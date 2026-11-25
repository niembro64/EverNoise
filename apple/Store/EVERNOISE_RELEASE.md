# EverNoise — build 9

Historical naming release; replaced by build 10. See `MINIMAL_UI_RELEASE.md`
for the current interface and release status.

Version 1.0 (9) is available in the internal Personal Testing group and is
Waiting for Review for the public App Store. Apple confirmed 1 Item Submitted
on November 14, 2026 at 10:32 AM CST. Automatic free release after approval
remains selected. It is not publicly available yet.

## Final naming and icon

The installed display name, main screen, Now Playing title, privacy text,
App Store name, screenshots, TestFlight notes, and support pages use EverNoise.
The existing bundle identifier and saved settings are preserved. The RGB infinity
icon remains in the production asset catalog and both iPhone/iPad icon entries
of the signed package. Its packaged PNGs match verified build 8 exactly.
Apple's actual build-9 included-icon preview was visually inspected and shows
the RGB infinity symbol on black. Both uploaded screenshots were inspected in
App Store Connect and show EverNoise and the Low/Mid/High pickers.

## Validation

- Release simulator and iOS archive builds, cloud-signed export, and upload passed.
  Upload completed at 16:25:58 UTC (10:25:58 AM CST).
- Strict code signature, bundle identifier, display name, version/build,
  background-audio mode, and distribution entitlements passed.
- Build 9 was installed and launched on the iPhone 17 Pro and iPad Pro 13-inch
  simulators. Both complete layouts were captured and visually inspected.
- Build 9 only changes naming, support links, and the build number relative to
  build 8. Production DSP, filters, NoiseMix, audio driver, and playback controller
  hashes are unchanged. All 23 production source/project/asset hashes and the
  signed package hash were checked after submission and match the manifest.
- Five actual iOS-engine integration tests and the full picker/lifecycle UI flow
  passed on build 8 during this session. Those tests were not repeated for the
  subsequent name-only build 9. The 29 core tests and 135 Apple-engine renders
  documented for build 7 cover the unchanged signal implementation and all
  125 mixes. See `BAND_PICKERS_AUDIT.md` for methods and bounds.
- Physical listening and overnight playback of build 9 remain unverified.
  The pause button and audio behavior are unchanged.

Package: `build/AppStore-v9/JustBrownNoise.ipa`.
SHA-256: `26e2dec93ae2a17f1fb0bc2c7c6fe9732ce44db933170aac18c697515a4f801b`.
Build/source record: `build-9-manifest.json`. Logs: `build/release-v9/`.
The incremental Release simulator build used `build/release-v8/Simulator`;
the device archive is `build/JustBrownNoise-v9-unsigned.xcarchive`.

## External confirmation

- App Store submission: `4d42cb7a-c43d-40d6-8140-974b9be23b46`,
  build ID `ec347735-529f-423b-8a81-f38818bb7f13`, Waiting for Review.
  `submission-confirmation.json` records the observed state and asset hashes.
- TestFlight: 1.0 (9), Testing, Personal Testing, one tester. Notes Saved was
  observed. The tester's last installed version observed was 1.0 (8).
  See `testflight-confirmation.json`.
- The prior Endless Noise build-8 submission was canceled for this replacement;
  Developer Rejected was observed. Historical evidence has the `-v8.json` suffix.
- Support and privacy: `https://niemo.io/evernoise/`. Both `endless-noise` and
  `just-brown-noise` URLs continue to work. All 12 live assets match source after
  decoding Cloudflare email obfuscation. The atomic public release contains
  189 verified files and preserves all 177 unrelated portfolio files. See
  `support-deployment.json` for hashes and rollback location.
