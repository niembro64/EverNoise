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
- Hosted [CI run 45652170698](https://github.com/niembro64/EverNoise/actions/runs/45652170698)
  passes both the macOS Apple core job and Linux Android/web build, lint and tests.
- The production web app was exercised in Edge. After enabling offline mode and
  reloading, its service worker supplied the app, AudioWorklet and WASM, and
  playback resumed without a network connection. Online mode was restored.
- All 40 public files in the live deployment match their local SHA-256 hashes.
  The additional `.nojekyll` hosting marker is deliberately not publicly served.
- The live F-Droid index passes signature/fingerprint verification with
  fdroidserver 2.4.6. The downloaded APK matches the tested release, passes APK v2
  signature verification, and passes 16 KiB ZIP alignment checks. All ARM64 and
  x86-64 native ELF load segments also have verified 16 KiB alignment. The public
  GitHub Release download has the same APK hash.

## Migration and publication

Android 1.0.0 (1), the web app, and the publisher-operated F-Droid repository are
live. Links and the release artifact hash are in [the launch record](LAUNCH_2026-11-25.md).
The central F-Droid catalog submission is prepared, but has not been submitted or
accepted. Apple store versions were not changed by this repository migration.

The original checkout's 50,803 file entries were audited: 50,789 are identical,
11 have intentional source/build/documentation changes, and three were already
broken generated-build symlinks. No file was missing. Original Git history is an
ancestor of the new main branch. The original checkout is recoverable from Trash;
its former path now resolves to the new repository.

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
