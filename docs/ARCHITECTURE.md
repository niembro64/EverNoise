# Platform architecture

The Apple app lives in `apple/`; its Xcode project references the Swift package at
the repository root. Compatibility symlinks in `apple/Sources/` keep older audit
scripts pointed at the canonical `shared/dsp` and `shared/analysis` code.

## Sound remains the authority

All three front ends use `BNMixRenderer.c`, its existing complementary coefficients,
edge tapers, loudness calibration, slow correction and peak protection. Native
48 kHz stereo float PCM is produced in fixed, bounded render calls. Controls are
smoothed in the renderer, not stepped by the UI. There are no looping audio assets.

Android has one owning audio thread. It uses a buffered `AudioTrack`, a media
foreground service, media session, audio focus and a partial wake lock held only
while playback needs it. Dead output objects are recreated with the generator's
state preserved and a new fade-in. A bounded retry limit surfaces persistent output
failures. Disconnecting headphones pauses, transient focus loss resumes on regain,
and permanent focus loss leaves sound paused. No automatic boot/start after
force-stop, and no bypass of Android battery policies.

The browser uses a WASM generator in an AudioWorklet, independent of the main UI
thread. The first tap resumes its audio context. Pause fades before suspending the
context. Browsers own background policy; the web UI documents this limitation and
offers an optional screen wake lock. It does not claim native background reliability.

## Analysis and visuals

Max analyzes post-protection PCM from both channels. Stereo powers are averaged,
so opposite-phase channels cannot cancel visually. All seven Hann windows, fourfold
zero padding, overlapping log-frequency kernels, three-stage temporal smoothing,
2 Hz–48 kHz axis, and fixed reference crossover colors are preserved.

Apple keeps Accelerate. The portable FFT packs left and right into one complex
transform and combines mirrored-bin energies. This halves the transform count
without changing the power measurement. The spectrum runs on a separate worker;
backpressure drops visualization data instead of delaying sound. Hidden/off modes
stop analysis. Missing/overrun sample clocks reset the analysis rather than bridge
an unobserved gap. Above Nyquist, rows are marked unavailable, not invented.

Android/web share a GLSL ES 3 material based on Apple's Metal artwork. Geometry,
C2 flow, spectrum palette floor, depth, and linear-light premultiplied compositing
are retained. Float literals and reserved names differ between shader languages.
The shader is not a library dependency of audio. Failure falls back to black UI.
Off does no ongoing drawing; Low is static, Med animates infinity, High adds four
large loops, and Max shows the spectrogram. Backgrounding stops visual work.

## State, privacy and distribution

Preferences are local (`SharedPreferences` / `localStorage`). Android requests no
network or microphone permission. The web app fetches its own static assets and
then caches them for offline use; it has no analytics or external runtime scripts.
Media notifications, the Android widget/tile and web Media Session control the
same playback instance. No timer is added.

Git stores source and public metadata. Build output, local device state, credentials
and signing keys are excluded. Signing keys are outside the checkout. The custom
F-Droid repository is publisher-operated; inclusion in F-Droid's central catalog
would be a separate review, not an automatic result of publishing this repository.
