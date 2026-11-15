# EverNoise

Source history is tracked in Git. The `sound-baseline-build-22` tag preserves the
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
otherwise upgrades start on Med. Every new level is remembered. Audio is unchanged.
The app remembers all three levels and fades smoothly between balances. A large
play/pause button controls playback; use the physical buttons for volume. Privacy
and help sit behind an outline gear with a generous 80-point touch target. Lock-screen and Control Center controls
work too. Reopening the app starts it again.

## TestFlight

Apple confirmed **1.0.1 (22)** is ready to test at 08:40:00 CST on November 15.
Open [TestFlight](https://testflight.apple.com/v1/app/6834413344) and update EverNoise.
Five direct buttons return for each sound band, with a reflective glass rim for
selection. New installations use buttons 3 / 3 / 2, counting Off as first;
your saved choices remain intact. The sound filters and engine are unchanged.
See `Store/testflight-confirmation-v22.json` for Apple's availability notification.
Public App Review submission and portal notes/screenshots still await browser
access. Installation of build 22 has not been observed.

## Run on your iPhone

1. Open `JustBrownNoise.xcodeproj` in Xcode 16 or newer (tested with Xcode 26.2).
2. Select the **JustBrownNoise** app target, then **Signing & Capabilities**.
3. Select your Apple developer team. Connect your iPhone and select it as the destination.
4. Run. For App Store distribution, use **Product → Archive → Distribute App**.

The generated project is included. To regenerate it after changing `project.yml`,
run `xcodegen generate`. There are no external app dependencies; `Package.swift`
contains only the local DSP and playback modules.

## Continuous audio

`AVAudioSourceNode` asks the C generator for samples on the audio render thread.
That path has no allocation, locks, file access, networking, or main-thread work.
Filter and 64-bit random-generator state persist between callbacks. The source
for Brown runs at 8 kHz; AVAudioEngine's mixer converts to the hardware route's format.
Build 2 uses a linear 18 Hz leaky integrator, two 35 Hz high-pass stages, and two
1,400 Hz low-pass stages for a softer, band-limited texture. Its measured slope
is about -6 dB/octave from 125–500 Hz. A constant gain bounds source samples to
0.75 without clipping or nonlinear peak shaping. There is no dynamic volume
normalization. Startup, pause, and resume use smooth fades.

The separate midrange and high-frequency layers run at 48 kHz. All three sources
keep running in one graph, including when their level is Off. Pickers adjust
each layer independently using 600 ms smoothstep fades without restarting audio.
These separately shaped layers overlap smoothly, but do not form a matched
power-complementary crossover. Equal settings keep a bass-heavy response; see
the [measured band-overlap audit](Store/BAND_OVERLAP_AUDIT.md).
All three bands use off, -18, -12, -6, and 0 dB relative to each layer's maximum:
equal 6 dB steps between active levels, with sample gains `10^(dB/20)`.
Low 4 / Mid 0 / High 0 exactly preserves Brown; Low 4 / Mid 0 / High 4 preserves
the previous Gray. Existing grid preferences migrate with Low at 4, preserving
all 25 old sounds. All three Off intentionally produces silence. Mids use a
linear band filter with four 600 Hz high-pass stages and four 3 kHz low-pass
stages, bounded by a constant creation-time gain.

Stereo is on when no preference exists, and preserves an explicitly saved Off.
A permanently allocated pair of independent generators
for every band supplies both channels. Mono duplicates the original left samples;
stereo selects the independent right source through a bounded one-second fade.
The Audio picker does not rebuild the graph or restart sound. Each channel keeps the
same filters and fixed source gains. The new two-channel conversion path removes
the old mono converter's 3.01 dB attenuation at 44.1 kHz; that route can sound
slightly louder than older builds at the same device volume. Tested 48 kHz mono
engine output is bit-identical. See the build-14 audit for exact comparisons.

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

See the [build-22 glass-button release record](Store/GLASS_BUTTONS_RELEASE.md).
All **31 distinct integration/UI tests pass** across the full run and a focused
visual rerun, plus both core preference tests. Coverage includes all 15 button
choices, edge taps, clear glass selection, saved balances, fresh defaults,
paused grayscale, Audio/animation preferences, and uninterrupted render counters.
The visual tolerance correction is documented with the measured native glass
edge pixels; the infinity still requires exact grayscale and stillness.

Nine audio/DSP/lifecycle sources and the compiled Metal library match build 21.
Only the fresh-install fallback changed in the preference model. Five production
engine renders measure the [current band overlap](Store/BAND_OVERLAP_AUDIT.md),
which is smooth but not power-complementary. The build-18
[linear-light and motion audits](Store/LINEAR_LIGHT_GLASS_RELEASE.md) remain the
shader baseline. The build-14 [audio baseline](Store/STEREO_RIBBONS_RELEASE.md)
includes 37 core tests, 199 engine renders, and 30 accelerated hours per band;
those extended runs were not repeated for this control/default change.
Physical-device battery savings and overnight listening remain unmeasured.

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

The last portal-confirmed App Review submission is **1.0.1 (build 15)**.
Apple confirmed **1 Item Submitted** on November 14, 2026, with automatic
release after approval. Its live status has not been refreshed; the latest
visual update is not yet submitted. See
[release evidence](Store/RELEASE_STATUS.md) for the separately tracked states.

Apple references: [background audio](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback),
[source-node rendering](https://developer.apple.com/documentation/avfaudio/avaudiosourcenode),
[interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions),
[media-service reset](https://developer.apple.com/library/archive/qa/qa1749/).
