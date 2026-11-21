# EverNoise

Source history is public at [niembro64/EverNoise](https://github.com/niembro64/EverNoise). The `sound-baseline-build-22` tag preserves the
last sound engine before the power-complementary redesign; see
[sound history and rollback](Store/SOUND_ENGINE_HISTORY.md). Account-specific
delivery confirmations, signing material, and generated builds remain local.

A small native SwiftUI app for iPhone and iPad (iOS 17+), also distributed as a
compatible iPad app on Apple silicon Macs (macOS 14+) and Apple Vision Pro.
The **EverNoiseTV** target adds a native Apple TV app for tvOS 17+, sharing the
same audio engine, sound controls, palette, and Metal artwork. Its landscape
layout supports remote focus and the Siri Remote Play/Pause button. Apple Watch
is intentionally outside the supported scope.
See [platform availability and validation](Store/PLATFORM_AVAILABILITY.md).
Opening it starts
the last selected balance (Low/Mid/High buttons 4 / 4 / 3 for a new installation, counting Off as the first button). Locking the screen or switching apps leaves the audio engine
running. There is no playback deadline, recording to loop, network dependency,
account, advertising, or subscription.

Three rows of six buttons run **High, Mid, Low** from top to bottom, matching
the spectrogram's frequency direction, each with Off and five
active levels. A hollow circle means Off; five growing, brighter dots show relative power.
A reflective glass rim identifies the selection, with no checkmark or pointer.
The new −30 dB trace contributes about one-sixteenth the power of the former
first active choice. All old weights and saved balances are preserved. Low/Mid/High headings
share the thin title font. The previous slider remains available in
`App/BandNotchPicker.swift`. Muted rose
represents lows, sage mids, and periwinkle highs. Avenir Next typography scales with your preferred text size throughout the app. A large liquid infinity fills the upper screen and
combines their color on a pure-black screen, with six rainbow currents weighted
by the bands' logarithmic power and soft nearby mist. Four enormous, fainter closed
ribbons float, turn, and bend across the entire screen at the High animation level. All share one liquid shader,
palette, and smooth clock. Background drift/rotation/bending now happens inside
one fixed Metal viewport, without animated SwiftUI texture transforms. The full
artwork is combined in linear light with premultiplied alpha and encoded once
for display. The rear infinity surface is darker and more translucent. Native
iOS 26 Liquid Glass buttons sample this artwork; older versions use system material. Motion
and colors change gradually, including rapid taps.
Pausing or turning all bands off fades the controls to grayscale and eases the
mark to rest. Animation suspends when hidden and respects Reduce Motion. Settings has native segmented
Audio (Mono/Stereo) and
Animations control: Off removes all artwork and stops visual processing; Low
keeps a still infinity on black; Med animates only the infinity; High also
shows the background ribbons; Max replaces the infinity with a spectrogram
of the actual generated audio. Its logarithmic frequency axis spans 2 Hz to
48 kHz, with a marked 24 kHz source measurement limit and approximately
22 seconds of time history. Fixed red/green/blue frequency colors follow the
equal-gain crossover curves. Brightness uses energy per octave, converted to
decibels and a fixed perceptual lightness curve, without automatic exposure.
Seven overlapping analysis windows, Gaussian frequency weighting, gentle
linear-power temporal smoothing, and 16-bit linear-light imagery soften the
frequency and time detail. Max computes 60 columns per second with 1024 rows;
a small presentation buffer absorbs uneven worker delivery. The longest bass
window resolves near 2 Hz; the first measurement takes about six seconds. Analysis runs off the audio
thread and stops while paused or hidden. Med is
the default. A saved old animations-off choice migrates to Low;
otherwise upgrades start on Med. Every new level is remembered. Animation settings do not affect audio.
The app remembers all three levels and fades smoothly between balances. A large
play/pause button controls playback; use the physical buttons for volume. Settings
also has a saved App Loudness setting to balance EverNoise against your other audio. Privacy
and help sit behind an outline gear with a generous 80-point touch target. Reopening the app starts it again.

Interactive Home Screen and Lock Screen widgets let you play or pause your
saved mix without opening EverNoise. On iOS 18+, a native control can be added
to Control Center, Lock Screen control slots or a supported Action button.
Start, Pause and Play or Pause actions are available in Siri and Shortcuts,
including bedtime automations. Settings includes a native audio-output picker
and a **Widgets & shortcuts** setup guide. Widgets stay still to save power.
The app keeps mixing with other audio; these dedicated controls work independently
of iOS's separate Now Playing media card. See [design and validation](Store/WIDGETS_RELEASE.md).

Settings includes **For the ones you care for**, describing a broad, adjustable
blanket of sound for households with babies, children and pets. It explains
individual hearing differences, the app's upper-human-audible coverage, and
the higher ranges dogs and cats can hear. Caregiver guidance covers quiet,
distant, limited listening for children and a quiet retreat for pets. Digital
peak protection is not a sound-pressure limit at anyone's ears.

## Public App Store

**1.1 (30)** now shows Ready for Distribution for iOS and tvOS. The new
**1.2 (31)** update was submitted on November 21 for both and is **Waiting for
Review**, with automatic release after approval. iPad, Apple silicon Mac and
Vision Pro share the iOS release; their availability remains enabled. The app
remains free. See [release status](Store/RELEASE_STATUS.md) and
[submission evidence](Store/app-store-submission-v31.json).

## TestFlight

**1.2 (31) is available in internal TestFlight** for iOS and Apple TV.
Open [TestFlight](https://testflight.apple.com/v1/app/6834413344) to update.
Friends and Family external testing is Waiting for Review on both platforms.
The update adds iPhone/iPad widgets, system controls, Siri/Shortcuts and an
output picker. Your existing mix, App Loudness and sound are preserved; all
19 audio/analysis/driver source files match build 30. See
[validation](Store/WIDGETS_RELEASE.md), [signed packages](Store/build-31-manifest.json)
and [delivery evidence](Store/delivery-v31.json).

The records below describe earlier distributed builds.

Apple confirmed **1.0.1 (23)** is ready to test at 09:45:04 CST on November 15.
Open [TestFlight](https://testflight.apple.com/v1/app/6834413344) and update EverNoise.
This build introduces the complementary sound engine. New installations still
use buttons 3 / 3 / 2, counting Off as first; saved choices remain intact, but
their tone and digital output level intentionally change. What to Test notes
are saved in App Store Connect. On November 15, the internal tester portal
reported build 23 installed. External TestFlight testing still awaited its
separate beta review at 15:11 CST; the same build is already public on the App Store.

Mac and Vision Pro testing are enabled for both existing tester groups. Build 23
was installed and launched through TestFlight on an Apple silicon Mac on
November 15. Refresh TestFlight if EverNoise still appears under Incompatible.
Apple confirmed **tvOS 1.1 (24)** ready to test at 17:04:28 CST the same day.
Open TestFlight on Apple TV with the existing internal tester's Apple Account.
External TV testing has been submitted for its separate beta review.
The TV version is also submitted for public App Review, with automatic release
after approval. It is not yet confirmed publicly available.

## Run on your iPhone

1. Open `JustBrownNoise.xcodeproj` in Xcode 26.2 or newer.
2. Check **Signing & Capabilities** for both **JustBrownNoise** and **EverNoiseWidgets**.
3. Use the same Apple developer team and App Group for both targets. Connect your iPhone and select it as the destination.
4. Run. For App Store distribution, use **Product → Archive → Distribute App**.

The generated project is included. To regenerate it after changing `project.yml`,
run `xcodegen generate`. There are no external app dependencies; `Package.swift`
contains only local DSP, playback and spectrum-analysis modules. Spectrum
analysis uses Apple's Accelerate framework.

For Apple TV, select the **EverNoiseTV** scheme and an Apple TV simulator or
registered device. Its test action runs the real audio-engine checks plus remote
navigation and background-continuity tests. `swift scripts/generate-tv-artwork.swift`
regenerates its layered app icons and Top Shelf images. See the
[TV release record](Store/TV_RELEASE.md) for build and distribution evidence.

## Continuous audio

Three independently excited, continuously running 48 kHz bands share a warm
pink-weighted base and complementary Butterworth splits at 200 Hz and 2 kHz.
The crossover power weights sum to one at every frequency. Build 28 adds a
fourth-order Butterworth high-pass at 30 Hz and moves the second-order low-pass
to 20 kHz. Both are shared by all bands, preserving crossover complementarity.
The lower taper removes much more impractical sub-bass; the upper taper retains
more of the high frequencies younger listeners may hear. There is no extra
ultrasonic source or treble boost for children or animals. See
[frequency-taper validation](Store/FAMILY_SPECTRUM_RELEASE.md). The complete
previous sound remains at `sound-baseline-build-27`; design-1 records are retained.

`AVAudioSourceNode` asks the C generator for samples on the audio render thread.
That path has no allocation, locks, file access, networking, or filter design.
Random and filter state persist between callbacks, including while a band is
Off. Build 25 added shared K-weighted mix normalization,
very slow bounded loudness correction, and linked lookahead peak protection.
The six choices describe relative band weights. A saved App Loudness preference
adjusts the target from -18 to +3 dB around a nominal -20 LUFS stereo level.
Peak protection retains a separate ceiling; the preference never changes system
volume. There is no hard clipping or saturation. Startup, pause, resume, and
mix changes remain smooth. Build 28 recalibrates each band's expected power for
the revised filters without changing dynamics, targets, or stored settings.
See [loudness design](Store/LOUDNESS_RELEASE.md).

All three controls offer Off / -30 / -18 / -12 / -6 / 0 dB, using sample gains
`10^(dB/20)`. Changes fade over 600 ms without restarting the engine. Saved
settings and the default −12/−12/−18 dB sound remain; the default buttons are
now 4 / 4 / 3. A single band alone keeps the same normalized loudness at any
active choice. All three Off produces exact silence. See
[mix resolution and validation](Store/MIX_RESOLUTION_RELEASE.md).

Stereo defaults on and preserves saved choices. Each band has a permanent pair
of independent left/right generators. Mono duplicates the left signal; the
one-second Mono/Stereo transition now normalizes the blend to preserve expected
right-channel power during the switch. Linked peak protection covers both channels. No graph rebuild
is needed. All bands use the same conversion path to the output sample rate.

The legacy generators remain available for comparison. Four actual-engine
comparisons at 44.1/48 kHz in Mono/Stereo match build 22 bit for bit. The tagged
baseline reproduces the complete old app, including its 8 kHz Brown source and
separately shaped Mid/High layers; see [sound history](Store/SOUND_ENGINE_HISTORY.md).

The `.playback` audio session and `UIBackgroundModes = audio` support background
and lock-screen playback. Mixing allows other apps to play without needlessly
stopping this sound. No scene-background handler stops or rebuilds the engine.
Audio session interruptions, route configuration changes, and media service
resets have separate recovery paths. Transient activation failures receive
retries with a backoff capped at 30 seconds while recovery remains appropriate;
healthy playback uses no periodic app timer.

iOS still controls audio access. Calls, Siri, route disconnections, OS failures,
force-quitting, or a powered-off device can stop sound. Interruption recovery
respects iOS's `shouldResume` flag. A media-services reset waits for a user action,
as Apple requires. Disconnecting headphones continues on the available output,
which may be the speaker. No app can guarantee immunity from system interruptions.

## Verification

Build 27 passes all **52 core tests**, **33 iOS and 10 tvOS integration tests**,
and affected visual flows on iPhone, iPad and Apple TV. Independent full-rate
and decimated FFT, anti-alias filtering, color/lightness and sanitizer checks
pass. Every audio DSP/playback/driver/capture source matches build 26, and
capture tests confirm sample-exact observation. Detailed results and
physical-device limitations are in the
[frequency-color spectrogram audit](Store/SPECTROGRAM_COLOR_RELEASE.md).

The following records describe the earlier sound-engine qualification.

See the [build-23 complementary sound audit](Store/POWER_COMPLEMENTARY_RELEASE.md).
All **40 core tests and 32 integration/UI tests pass**; the integration/UI suite
passes in one run. All 125 mixes, 32 output-route cases, rapid/mute transitions,
and measured spectra pass in 164 new-engine renders. The largest measured
reconstructed peak is 0.1011 full scale. Each new paired generator passed 30
accelerated hours and 5.184 billion frames per channel, including 2,916 stereo
changes. This is not an overnight physical-device qualification.

The actual compiled filters' power sum matches their common spectrum within
1.21e-13. Adversarial-input and linearity checks confirm the fixed headroom
bound. The [comparison graph](Store/complementary-spectrum-v23.png) shows the
new sound beside the old favorite at equal total RMS for tone comparison.
The new default's unnormalized digital RMS is 8.79 dB lower; perceived loudness
also depends on the spectrum and output device.

Build 23's iOS UI and animation code was unchanged from build 22. The TV port
shares that shader and audio path, with a separate landscape interface. Build-18
[linear-light and motion audits](Store/LINEAR_LIGHT_GLASS_RELEASE.md) remain the
shader baseline. Legacy DSP/audit records below describe the previous engine.
Physical-device listening, battery, Bluetooth, and overnight playback remain
unmeasured for the new generator.

The [build-7 picker audit](Store/BAND_PICKERS_AUDIT.md) covers all 125 balances,
low-band scaling, persistence migration, headroom, and continuity. The
[build-6 logarithmic-scale audit](Store/LOG_SCALE_AUDIT.md) covers measured
layer power, equal decibel steps, and unchanged endpoints. The
[build-5 sound-grid audit](Store/SOUND_GRID_AUDIT.md) covers all 25 balances,
constant-bass measurements, headroom, transitions, and exact Brown preservation.
29 core tests, five real-engine integration tests, and the UI test pass. For
build 7, 135 Apple-engine renders cover every mix, rapid transitions, deliberate
mute/restore, and output conversion. All 25 previous balances remain exactly
unchanged with Low at 4. Earlier 48-hour accelerated tests cover the unchanged
filters. The user confirmed smooth Brown sound on the iPhone speaker; listening
to the latest picker release and an overnight physical-device test are still pending.

Before depending on a release overnight, test on the intended physical iPhone
and audio output: at least 12 hours locked, Low Power Mode, charging, incoming
call/Siri, headphone/Bluetooth disconnect, and changing audio routes. A simulator
cannot qualify physical-device battery, Bluetooth, or all interruption behavior.

## App Store

Listing text is in `Store/metadata.json`; support/privacy pages are in `Store/site`.
Version **1.0.1 (build 23) is publicly available for free** on the
[App Store](https://apps.apple.com/us/app/evernoise/id6834413344).
Apple's US storefront reports release at **14:44:13 CST on November 15, 2026**;
App Store Connect confirms build 23 is **Ready for Distribution**. The public
listing includes the complementary engine description and current screenshots. See
[release evidence](Store/RELEASE_STATUS.md) for the separately tracked states.

Apple references: [background audio](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback),
[source-node rendering](https://developer.apple.com/documentation/avfaudio/avaudiosourcenode),
[interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions),
[media-service reset](https://developer.apple.com/library/archive/qa/qa1749/).
