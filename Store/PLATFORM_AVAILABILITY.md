# Apple platform availability — November 21, 2026

## Current release and update

App Store Connect now lists **iOS 1.1 (30) and tvOS 1.1 (30) as Ready for
Distribution**. Version **1.2 (31)** was submitted on November 21 for both
platforms and is **Waiting for Review**, with automatic release after approval.
Build 31 is available in internal TestFlight on both; external testing is in
its separate review queue.

The universal iOS release covers iPhone/iPad and the compatible iPad app on
Apple silicon Mac and Vision Pro. Both availability checkboxes remain enabled,
and Apple explicitly lists version 1.2 as compatible with each. There is no
separate native macOS or visionOS target, and no Intel Mac support. The native
Apple TV target shares the same audio sources. Apple Watch remains excluded.
The app remains free across the existing 175 territories.

Build 31 adds interactive widgets, native system controls and Siri/Shortcuts
for iPhone/iPad. These extension surfaces have not been physically tested on
Mac or Vision Pro. iPhone, iPad and TV simulator checks passed; see
[widget validation](WIDGETS_RELEASE.md), [submission evidence](app-store-submission-v31.json)
and [release status](RELEASE_STATUS.md). The Mac smoke test below is historical
build-23 evidence, not a fresh hardware test of build 31. Storefront propagation
on each physical device was not independently verified.

## Original platform rollout — November 15

At approximately 22:33 UTC (16:33 CST), distribution was expanded using the
existing, released **1.0.1 (23)** binary. No audio or application code changed.

| Platform | Distribution state | Validation |
| --- | --- | --- |
| iPhone | Public App Store; internal TestFlight | Existing released iOS app |
| iPad | Public App Store; internal TestFlight | Existing universal iOS target, device families 1 and 2 |
| Apple silicon Mac | Mac App Store availability enabled; TestFlight enabled | Installed build 23 through TestFlight on macOS 26.6.2; launched successfully |
| Apple Vision Pro | App Store availability and TestFlight enabled | App Store Connect reports version 1.0.1 compatible; no headset test performed |
| Intel Mac | No native Mac release | The iOS-on-Mac distribution route requires Apple silicon |
| Apple TV | Native tvOS 17+ version 1.1 (24) available in internal TestFlight; submitted for public App Review and external beta review | 8 real-engine and 2 remote/background UI tests pass; Release simulator layout inspected |
| Apple Watch | Intentionally excluded | User selected iPad, Mac, Vision Pro, and Apple TV |

## Confirmed changes

- Enabled **Test iPhone and iPad Apps on Apple Silicon Macs** in both existing
  TestFlight groups: Personal Testing and Friends and Family.
- Enabled **Test iPhone and iPad Apps on Apple Vision Pro** in both groups.
- Enabled **Make this app available** under Apple Silicon Mac Availability in
  Pricing and Availability, retaining Automatic (macOS 14.0).
- Enabled **Make this app available on Apple Vision Pro**.
- Saved the availability changes, reloaded the page, and verified both
  checkboxes remained enabled. Storefront propagation was not independently
  verified on each device.
- TestFlight on the Mac changed from **Incompatible** to **Works on this Mac**.
  Installation completed and its offer changed to **Open**.

## Mac smoke test

The TestFlight installation opened with the expected infinity artwork, five
buttons per band, and default 3 / 3 / 2 positions counting Off as first. Its
accessibility status reported **Playing continuously**. Pause changed this to
**Paused**, and Play restored **Playing continuously**. Settings opened and
showed Stereo and Med selected. Returning from Settings and spending several
minutes working in another app left playback reporting **Playing continuously**.
The app was left running.

These checks establish installation and UI/playback state transitions. They do
not establish audible output quality, overnight continuity, hardware sleep
behavior, or physical-headset/Apple-TV compatibility. The optional App Store Connect
Mac compatibility attestation was not submitted.

## Apple TV

The native `EverNoiseTV` target shares the existing production audio sources and
shader unchanged. It adds a landscape layout, remote focus, Play/Pause remote
support, Settings, layered infinity icons, and Top Shelf artwork. Version 1.1
(24) uploaded successfully at **23:02:27 UTC (17:02 CST)**. The iOS release stays
at 1.0.1 (23); the Mac and Vision Pro availability changes use that existing build.
See the [TV release record](TV_RELEASE.md) for final review status and tests.

## Distribution references

- [EverNoise on the App Store](https://apps.apple.com/us/app/evernoise/id6834413344)
- [Test iPhone and iPad apps on Macs with Apple silicon](https://developer.apple.com/help/app-store-connect/test-a-beta-version/test-iphone-and-ipad-apps-on-macs-with-apple-silicon/)
- [Manage Mac availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-macs-with-apple-silicon)
- [Manage Apple Vision Pro availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-apple-vision-pro/)

External TestFlight review remains a separate requirement from these platform
switches and from the completed public App Store review.
