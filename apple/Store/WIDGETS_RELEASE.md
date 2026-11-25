# Widgets and system playback — 1.2 (31)

Build 31 adds ways to start and pause the saved sound without navigating into
EverNoise. The audio generator, filters, loudness control, peak protection,
capture and spectrum-analysis sources match build 30 exactly.

## Controls

- Small and medium interactive Home Screen widgets, also usable in StandBy.
- Circular and rectangular Lock Screen widgets (iOS/iPadOS 17+).
- A native WidgetKit control for Control Center, Lock Screen control slots and
  the Action button on supported devices (iOS/iPadOS 18+).
- Start, Pause and Play or Pause actions in Shortcuts. Automatic Siri phrases
  include “Start EverNoise”, “Pause EverNoise” and “Toggle EverNoise”.
- A native audio-output picker and a **Widgets & shortcuts** guide in Settings.

Widgets use a static, dark layout with readable muted text while paused and a
soft periwinkle accent while playing. The medium widget shows the saved band
balance. They add no animation work. Users add widgets or controls themselves
through Apple's galleries; installation does not alter their screen layouts.

The iOS app remains universal for iPhone/iPad and available as the compatible
iPad app on Apple silicon Mac and Vision Pro. These are not new native Mac or
visionOS targets. The widget/control feature is advertised for iPhone/iPad;
Mac and headset widget surfaces were not tested. Native tvOS build 31 retains
the existing UI and Siri Remote controls, plus the shared idle-pause refinement.

## Playback and state

`AudioPlaybackIntent` routes actions into the containing application, including
a cold background launch. All entry points use the same main-actor
`AudioService.shared`; the widget extension contains no audio engine. Start and
Pause are idempotent, and Toggle reads the actual service state rather than a
possibly old widget image. Unavailable playback reports an error.

Autoplay now occurs on first foreground activation or return from the
background. Merely launching for a background Pause intent, or dismissing Siri
or Control Center, does not restart playback. An idle service does not publish
Now Playing information until it has actually played.

The application writes a small presentation snapshot into App Group
`group.io.niemo.EverNoise`. A nonblocking lifetime file lock indicates that a
playing application process still exists; the OS releases it on termination.
Readers turn stale “playing” data into paused state. Updates are atomic and
remain accessible after first device unlock. There is no heartbeat, continuous
app timer, or shared-file access on the audio render thread. Widget timelines
reload on changes, with an OS-scheduled 15-minute fallback. iOS controls refresh
timing, so a rendered widget can briefly lag after abnormal termination.

The existing `.mixWithOthers` audio session is preserved. Apple's ordinary
Now Playing media card requires a nonmixable session; dedicated EverNoise
widgets and controls provide lock-screen playback independently of that card.
Opening the application still starts the saved mix. All bands Off stays silent.
Normal system interruptions, force quitting, device shutdown and hardware sleep
constraints still apply.

## Validation

| Check | Final result |
| --- | --- |
| Swift core tests | 55 passed |
| Signed iOS integration tests | 44 passed |
| tvOS integration tests | 17 passed |
| iPhone UI flows | 2 passed: background/reopen and system-controls guide |
| iPad UI flow | 1 passed: system-controls guide and playback |
| Release archives and distribution exports | iOS and tvOS passed |
| Distribution signatures | Strict verification passed |
| App Group entitlements and profiles | Present in both final iOS app and extension |
| Siri shortcut metadata | Packaged, including compiled NLU assets |
| Unchanged sound implementation | 19 audio/analysis/driver source hashes match build 30 |

Manual iOS 26.2 simulator checks used the actual system galleries and shipped
widget/control implementation:

- Added a small Home Screen widget; Play and Pause stayed on the Home Screen
  and changed both playback state and the widget. Checked paused text contrast
  after the final layout correction.
- Added a rectangular Lock Screen widget; Play changed its caption to Playing
  and Pause restored Play your sound while the Lock Screen remained visible.
- Selected the native EverNoise control in Action Button settings. The simulated
  Action button started and paused playback without opening the app, both while
  another app was visible and while the device was locked.
- Inspected circular and rectangular accessory previews in the widget gallery.

Control Center placement itself could not be exercised reliably with this
simulator's gestures; the same native ControlWidget was exercised through the
Action button. Voice-triggered Siri, StandBy, physical-device Bluetooth/AirPlay,
passcode/first-unlock behavior, overnight audio and acoustic measurements were
not performed. The iOS 17 fallback compiles; runtime checks used iOS 26.2.
Simulator UI stalls required restarting the simulator and did not count as
successful checks. The final sequential, signed test runs above passed.

Local result bundles (ignored build artifacts):

- `build/widgets-signed-integration-retry.xcresult`
- `build/widgets-tv-integration.xcresult`
- `build/widgets-iphone-ui.xcresult`
- `build/widgets-ipad-ui.xcresult`
- `build/widgets-core-tests.log`

## Signing and reproduction

The main app and widget have the same registered App Group. Xcode's automatic
distribution export initially omitted the group from an unsigned archive. This
was caught before upload. When archiving with `CODE_SIGNING_ALLOWED=NO`, first
ad-hoc sign the embedded extension, then the containing application, each with
`App/EverNoise.entitlements`. Export with `Store/ExportOptions.plist` and
`-allowProvisioningUpdates`. Verify the final distribution entitlements **and**
embedded profiles for both executables before upload. A successful export alone
does not prove the group survived signing.

Both Info.plists declare English as their development language. The app also
declares its English localization; this lets Xcode compile the App Shortcuts
NLU metadata. Omitting these keys caused the initial Siri-phrase archive check
to fail. The final archive includes the compiled assets.

The exported iOS package is
`build/widgets/iOS-AppStore-final/JustBrownNoise.ipa`; TV is
`build/widgets/TV-AppStore/EverNoiseTV.ipa`. The upload step exports/signs from
the same validated archives. Source and package hashes are recorded in
[build-31-manifest.json](build-31-manifest.json). See
[delivery-v31.json](delivery-v31.json) and
[app-store-submission-v31.json](app-store-submission-v31.json) for external state.

## Apple API references

- [Interactive widgets and execution context](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- [System controls](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system)
- [AudioPlaybackIntent](https://developer.apple.com/documentation/appintents/audioplaybackintent)
- [Now Playing session eligibility](https://developer.apple.com/videos/play/wwdc2022/110338/)
