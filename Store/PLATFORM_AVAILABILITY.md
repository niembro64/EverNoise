# Apple platform availability — November 15, 2026

At approximately 22:33 UTC (16:33 CST), distribution was expanded using the
existing, released **1.0.1 (23)** binary. No audio or application code changed.

| Platform | Distribution state | Validation |
| --- | --- | --- |
| iPhone | Public App Store; internal TestFlight | Existing released iOS app |
| iPad | Public App Store; internal TestFlight | Existing universal iOS target, device families 1 and 2 |
| Apple silicon Mac | Mac App Store availability enabled; TestFlight enabled | Installed build 23 through TestFlight on macOS 26.6.2; launched successfully |
| Apple Vision Pro | App Store availability and TestFlight enabled | App Store Connect reports version 1.0.1 compatible; no headset test performed |
| Intel Mac | No native Mac release | The iOS-on-Mac distribution route requires Apple silicon |
| Apple TV | No tvOS target or release yet | Requires a separate app target and remote-friendly interface |
| Apple Watch | No watchOS target or release yet | Requires a separate app target and watchOS audio-session handling |

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
behavior, or headset/Apple TV/Watch compatibility. The optional App Store Connect
Mac compatibility attestation was not submitted.

## Distribution references

- [EverNoise on the App Store](https://apps.apple.com/us/app/evernoise/id6834413344)
- [Test iPhone and iPad apps on Macs with Apple silicon](https://developer.apple.com/help/app-store-connect/test-a-beta-version/test-iphone-and-ipad-apps-on-macs-with-apple-silicon/)
- [Manage Mac availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-macs-with-apple-silicon)
- [Manage Apple Vision Pro availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-apple-vision-pro/)

External TestFlight review remains a separate requirement from these platform
switches and from the completed public App Store review.
