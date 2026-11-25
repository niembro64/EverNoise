# EverNoise

**Your sound. All night.** Free, continuous noise for Apple devices, Android, and the web.

- [Open the web app](https://niemo.io/evernoise/app/)
- [Apple App Store](https://apps.apple.com/app/evernoise/id6834413344)
- [Android downloads](https://github.com/niembro64/EverNoise/releases)
- [Android installation and F-Droid repository](https://niemo.io/evernoise/app/android.html)

Shape Low, Mid, and High with six logarithmic mix choices. Keep your App Loudness,
choose mono or independent stereo, and use quiet infinity artwork or the live output
spectrogram. No sound files to loop, playback timer, account, ads, or tracking.

Native apps support background audio. Browsers require an initial tap and can
suspend audio when hidden or locked. For overnight listening, use a native app.
Calls, audio-focus changes, force-stop, OS battery restrictions, and shutdown can
interrupt any app; this project does not promise immunity to the operating system.

## Workspace

| Folder | Purpose |
| --- | --- |
| `apple/` | Existing SwiftUI iPhone/iPad, Apple silicon Mac, Vision Pro compatibility, tvOS, widgets and release history |
| `android/` | Native Java interface, Android media service, JNI, widget and Quick Settings tile |
| `web/` | Installable offline web app, AudioWorklet + WebAssembly, WebGL artwork |
| `shared/dsp/` | One canonical C generator, complementary filters, loudness and peak protection |
| `shared/analysis/` | Seven-window, 1,024-row spectral analysis; Accelerate or portable FFT |
| `shared/visuals/` | Shared Android/web GLSL port of the Apple liquid ribbon material |
| `distribution/` | Public F-Droid metadata; no signing secrets |
| `scripts/`, `docs/` | Build, verification and release procedures |

The original Git history is preserved. The Apple generator has not been replaced
with a new approximation. Android and web compile the same renderer; the web's
reference-seeded output matches the native Apple output sample for sample.
See [architecture](docs/ARCHITECTURE.md) and [port validation](docs/PORT_VALIDATION.md).

## Build and test

Apple requires macOS, Xcode 26.2+, XcodeGen and Swift 6:

```sh
swift test
cd apple
xcodegen generate
xcodebuild -project JustBrownNoise.xcodeproj -scheme JustBrownNoise \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Android requires JDK 17+, Android SDK 36, NDK 27.1.12297006 and CMake 3.22.1:

```sh
export ANDROID_HOME="$HOME/Library/Android/sdk" # use your SDK path
android/gradlew -p android assembleDebug lintDebug
# With an API 36 emulator/device connected:
android/gradlew -p android connectedDebugAndroidTest
```

The application supports Android 8+ on ARM64 and x86-64. Release signing is optional
for local builds: `assembleRelease` produces an unsigned APK without signing env vars.
See [release instructions](docs/RELEASING.md) for a signed build and repository updates.

Web requires Node 24+ and Emscripten 4.0.20. The C engine is compiled locally, not
loaded from a third-party CDN:

```sh
git clone --depth 1 --branch 4.0.20 https://github.com/emscripten-core/emsdk.git tools/emsdk
tools/emsdk/emsdk install 4.0.20
tools/emsdk/emsdk activate 4.0.20
scripts/build-wasm.sh
node --test web/tests/*.test.mjs
node web/scripts/build.mjs
node web/scripts/serve.mjs # http://127.0.0.1:4173
```

On macOS, `scripts/test-ports.sh` also compares the portable FFT against Accelerate
and the WebAssembly output against native PCM. For real-browser integration checks,
copy `web/tests/browser.html` to `web/dist/check.html` and open that page locally.
It checks shader compilation, actual AudioWorklet output, the analysis worker,
suspension after pausing, and resuming. The test page is not in production builds.

## License

MIT, copyright Eric Niemeyer. See [LICENSE](LICENSE). Developed with AI assistance.
Platform SDKs and build tools retain their own licenses and are not vendored here.
