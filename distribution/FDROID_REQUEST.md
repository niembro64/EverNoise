# EverNoise — request for central-catalog packaging

App: EverNoise

Source: https://github.com/niembro64/EverNoise

License: MIT

Package ID: io.niemo.evernoise

Description: Free, on-device continuous noise with six relative levels for each
of three complementary bands, saved loudness, independent stereo, background
media playback, widget/tile controls, and optional liquid artwork/spectrogram.
There are no ads, trackers, microphone, account, or Internet permission.

The Android app is a new native Java/JNI port of an existing Apple app
(https://apps.apple.com/app/evernoise/id6834413344). The shared C renderer, tests,
and Git history are public. Development used AI assistance. Please assess the
normal project-age requirement; the Android port is new and we are not claiming
three months of Android releases.

Build from source: Gradle project subdirectory `android`, task `assembleRelease`,
JDK 17+, compile/target SDK 36, NDK 27.1.12297006, CMake 3.22.1. No third-party Java
runtime dependencies; the source for JNI/analysis is at `shared/`. No signing env
vars are needed for an unsigned release build. Native ABIs: arm64-v8a, x86_64;
minimum Android 8/API 26. The web-only WASM generation is not needed for Android.

Public metadata is in `distribution/metadata/io.niemo.evernoise.yml`. The build
was tested on an API 36 ARM64 emulator, plus numeric parity tests against Apple
and WebAssembly. Physical overnight Android endurance remains unverified.

This file is a prepared submission, not proof of central-catalog acceptance.
