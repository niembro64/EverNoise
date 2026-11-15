# EverNoise

Source history is public at [niembro64/EverNoise](https://github.com/niembro64/EverNoise). The `sound-baseline-build-22` tag preserves the
last sound engine before the power-complementary redesign; see
[sound history and rollback](Store/SOUND_ENGINE_HISTORY.md). Account-specific
delivery confirmations, signing material, and generated builds remain local.

A small native SwiftUI app for iPhone and iPad (iOS 17+). Opening it starts
the last selected balance (buttons 3 / 3 / 2 for a new installation, counting Off as the first button). Locking the screen or switching apps leaves the audio engine
running. There is no playback deadline, recording to loop, network dependency,
account, advertising, or subscription.

Three rows of five buttons control Low, Mid, and High, each with Off and four
active levels. A hollow circle means Off; four growing dots show intensity.
A reflective glass rim identifies the selection, with no checkmark or pointer.
The same five levels and saved balances are preserved. Low/Mid/High headings
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
Animations control: Low keeps a still infinity on black and stops scheduled
visual updates; Med animates only the infinity; High also shows the background
ribbons. Med is the default. A saved old animations-off choice migrates to Low;
otherwise upgrades start on Med. Every new level is remembered. Animation settings do not affect audio.
The app remembers all three levels and fades smoothly between balances. A large
play/pause button controls playback; use the physical buttons for volume. Privacy
and help sit behind an outline gear with a generous 80-point touch target. Lock-screen and Control Center controls
work too. Reopening the app starts it again.

## TestFlight

Apple confirmed **1.0.1 (23)** is ready to test at 09:45:04 CST on November 15.
Open [TestFlight](https://testflight.apple.com/v1/app/6834413344) and update EverNoise.
This build introduces the complementary sound engine. New installations still
use buttons 3 / 3 / 2, counting Off as first; saved choices remain intact, but
their tone and digital output level intentionally change. What to Test notes
are saved in App Store Connect. Installation of build 23 has not been observed.

## Run on your iPhone

1. Open `JustBrownNoise.xcodeproj` in Xcode 16 or newer (tested with Xcode 26.2).
2. Select the **JustBrownNoise** app target, then **Signing & Capabilities**.
3. Select your Apple developer team. Connect your iPhone and select it as the destination.
4. Run. For App Store distribution, use **Product → Archive → Distribute App**.

The generated project is included. To regenerate it after changing `project.yml`,
run `xcodegen generate`. There are no external app dependencies; `Package.swift`
contains only the local DSP and playback modules.

## Continuous audio

Build 23 is a fundamental change in sound generation. Three independently
excited, continuously running 48 kHz bands share a warm pink-weighted base and
complementary Butterworth splits at 200 Hz and 2 kHz. At equal settings their
powers sum to the designed base curve, with 20 Hz/18 kHz edge rolloffs. The
current filter math, spectrum, and bounds are documented in the
[complementary sound audit](Store/POWER_COMPLEMENTARY_RELEASE.md).

`AVAudioSourceNode` asks the C generator for samples on the audio render thread.
That path has no allocation, locks, file access, networking, or filter design.
Random and filter state persist between callbacks, including while a band is
Off. One fixed common gain bounds the sum below 0.8 full scale before output
conversion. There is no clipping, limiting, compression, or dynamic normalization.
Startup, pause, resume, and level changes use the existing smooth fades.

All three controls retain Off / -18 / -12 / -6 / 0 dB, using sample gains
`10^(dB/20)`. Changes fade over 600 ms without restarting the engine. Saved
settings and the default buttons 3 / 3 / 2 remain, but their sound intentionally
changes with the new generator. All three Off produces exact silence.

Stereo defaults on and preserves saved choices. Each band has a permanent pair
of independent left/right generators. Mono duplicates the left signal; the
one-second convex Mono/Stereo transition keeps its existing bounded behavior.
It can briefly reduce right-channel power during the switch. No graph rebuild
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

The UI and animation code is unchanged from build 22. Build-18
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
Version **1.0 (build 11) is publicly listed for free** on the
[App Store](https://apps.apple.com/us/app/evernoise/id6834413344). Apple approved
it while the animation update was being prepared.

**1.0.1 (build 23) is submitted for App Review.** Apple confirmed
**1 Item Submitted** on November 15, 2026. The listing, review notes, and current
phone/tablet screenshots are saved. Automatic release to all users after
approval is selected. Approval and public release of 1.0.1 are not yet confirmed. See
[release evidence](Store/RELEASE_STATUS.md) for the separately tracked states.

Apple references: [background audio](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback),
[source-node rendering](https://developer.apple.com/documentation/avfaudio/avaudiosourcenode),
[interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions),
[media-service reset](https://developer.apple.com/library/archive/qa/qa1749/).
