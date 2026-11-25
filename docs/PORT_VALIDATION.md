# Android and web validation — November 25, 2026

Environment: Apple M1 Max Mac Studio, macOS 26.6.2, Xcode 26.2, JDK 21,
Android SDK/API 36 arm64 emulator, NDK 27.1.12297006, Gradle 8.13/AGP 8.13.2,
Emscripten 4.0.20 and Node 24.1.0. This is emulator and browser validation, not
an overnight test on physical Android hardware.

- The migrated Swift package passes 55 tests across seven suites.
- iOS and tvOS Simulator builds succeed using the new root package paths, including the iOS widgets.
- Fixed-seed WebAssembly PCM matches 204,800 native Apple stereo frames exactly
  (maximum absolute sample difference 0).
- Portable packed-stereo FFT vs Accelerate: maximum difference 0.000184 dB across
  119 rows above −100 dB, using independent and opposite-phase multitone inputs.
- A 1 kHz tone resolves at 996.60 Hz on the shared log grid; rows above source
  Nyquist remain unavailable. The portable analysis processes 11.95 seconds of
  input in approximately 5–6 seconds on this machine after the FFT optimization.
- Browser checks pass shader compilation, live AudioWorklet start, finite nonzero
  PCM, worker spectrum delivery, actual context suspension after pause and resume.
- Five Android instrumentation tests and Android lint pass.
- Android device tests exercise JNI capture parity, headroom, independent stereo,
  fade-in/out, background frame continuity, zero observed AudioTrack underruns,
  transient audio-focus loss/regain, saved preferences, and Max analysis playback.

## Important limits

The same signal code and headroom behavior do not guarantee identical loudness on
different speakers, OS processing chains, Bluetooth routes, or browser mixers.
Hardware listening, Bluetooth reconnect, phone calls, vendor-specific battery
management and overnight endurance still merit real-device testing. Desktop
browser results do not establish reliable locked-phone browser playback.

MAX visualization can drop visual blocks on slow hardware. It never waits on the
audio thread. Off, Low and Med remain available. Pausing/context interruption and
other-app focus changes are handled explicitly; force-stop and device shutdown
cannot be worked around by an audio app.

Native screenshots also verify the Med/High/Max/Off states. A full-screen keyboard
focus highlight was removed from the scroll container so the background remains
pure black, while interactive controls retain their focus feedback.

Local logs and test screenshots are in ignored `artifacts/` and Android's build
reports. `scripts/test-ports.sh`, `swift test`, Android `connectedDebugAndroidTest`
and `web/tests/browser.html` reproduce the primary checks. No private test-device
or signing state is part of the public repo.
