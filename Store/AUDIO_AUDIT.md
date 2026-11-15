# Audio audit — builds 2–3, November 13, 2026

The reported problem is distortion on the iPhone speaker at both quiet and loud
volume, while other brown-noise apps sound smooth. Build 2 replaces the original
nonlinear generator with a linear, band-limited brown-noise filter and repairs
several interruption and pause paths. Physical iPhone listening and overnight
playback remain unverified; the measurements below do not establish subjective
speaker quality or immunity from iOS interruptions.

Build 3 contains exactly the same DSP and audio driver as build 2. It additionally
distinguishes returning from the background from temporary inactivity, so closing
Control Center or Siri does not itself undo a pause. The final build-3 integration
and UI tests cover restart after an actual background/reopen. Remote toggle also
correctly resumes after iOS denies an automatic resume, while still allowing a
toggle during an active interruption to cancel the earlier playback intent.

## Findings and signal changes

Build 1 did not hit digital full scale in the measured samples. However, it
applied `x / (1 + abs(x))` to **every** sample. That reshapes the waveform even
at modest levels. An isolated test of that stage with a 1 kHz sine at 0.22 RMS
produced 4.54% harmonic distortion. This is a diagnostic of the old stage,
not a measurement of the entire noise signal or proof of the sole audible cause.
The earlier peak/buffer tests did not detect this defect.

Build 1 also put 34.32% of measured signal energy below 20 Hz. Such energy uses
headroom without contributing useful audible brown noise. Its interaction with
an iPhone's speaker processing is a plausible additional contributor, not an
established hardware diagnosis.

Build 2 uses these linear stages:

1. An 18 Hz leaky integrator provides the descending brown-noise spectrum.
2. Two 35 Hz high-pass stages remove DC and reduce sub-bass.
3. Two non-resonant 1,400 Hz low-pass stages soften the upper texture.
4. A **constant** gain is calculated once when the generator is created.

There is no limiter, clipping function, compressor, automatic gain control,
per-buffer normalization, or periodic gain adjustment. Natural random level
variation remains. Startup and explicit pause/resume have separate smooth fades.

The source runs at 8 kHz, deliberately limiting its bandwidth to 4 kHz; the
AVAudioEngine mixer converts to the output route's native format. This is not an
8 kHz hardware-session request. The preferred hardware format remains 48 kHz.
The lower source rate provides useful noise power with conservative fixed gain;
it also reduces render work. There is no microphone or voice-processing mode.

### Peak bound

The white excitation is symmetric and strictly inside [-1, 1]. For a stable
linear filter, the absolute output is bounded by the sum of absolute impulse
coefficients times the input bound. Construction computes one second of the
first three stages' impulse response, adds a conservative bound on the complete
remaining tail, and scales that sum to just below 0.75. The two final low-pass
stages have nonnegative impulse coefficients summing to one, so they cannot
increase the bound. The fade gain is always between zero and one.

This establishes a **source-sample** ceiling of 0.75 (2.50 dB below full scale),
with rounding margin, without altering peaks as they occur. It is not a proof
about every hardware DAC, speaker processor, Bluetooth codec, or mixed signal.
Apple's conversion and estimated intersample peaks were measured separately.

## Measurements

| Check | Result |
|---|---|
| Production C renderer, 48 accelerated hours | 1,382,400,000 samples; 1,350,000 buffers; no invalid/full-scale samples or silent buffers |
| 48-hour level | RMS 0.044376; peak 0.250591 (about -12.02 dBFS); mean rounded to 0.00000000 |
| 48-hour maximum adjacent-sample change | 0.033587 overall; 0.030551 across callback boundaries |
| 64-second source spectrum | -6.03 dB/octave from 125–500 Hz; 2.55% energy below 20 Hz |
| 64-second estimated intersample peak | 0.199209 (-14.01 dBFS), independent 8x interpolation |
| Filter superposition at 8–384 kHz | Maximum error below 6e-16 in double precision |
| Production filter, 100 Hz / 1 kHz sine tests | Harmonics at numerical roundoff; no intentional nonlinear stage |
| Full-scale steps and alternating excitation | Peak at most 0.566865; measured complete impulse L1 at most 0.749204 |
| Independent transfer-function comparison | 95th-percentile PSD shape error 1.10 dB, consistent with a finite random sample |
| Core tests | 20 tests passed, including five sample-rate cases, channel layout, callback partitioning, fades, and playback recovery |
| iOS 26.2 simulator | Three real-engine integration tests and one UI test passed |

Actual AVAudioSourceNode → main mixer → output-format conversion was rendered
offline for 120 seconds in each case:

| Output | RMS | Sample peak | Estimated 8x peak | Silent buffers / render retries |
|---|---:|---:|---:|---:|
| 48 kHz stereo | 0.044287 | 0.198854 | 0.198986 | 0 / 0 |
| 44.1 kHz stereo | 0.031316 | 0.140589 | 0.140682 | 0 / 0 |
| 16 kHz stereo | 0.044287 | 0.198658 | 0.198854 | 0 / 0 |
| 48 kHz mono output | 0.044287 | 0.198854 | 0.198986 | 0 / 0 |

Both stereo channels matched exactly. The 44.1 kHz path attenuated the signal
by about 3.01 dB in this macOS AVAudioEngine configuration; its spectral shape
matched the other paths. The original audit's RMS lower threshold incorrectly
classified this attenuation as a failure. No clipping or dropout was found.
These are real Apple software-conversion tests, not recordings from an iPhone.

[Machine-readable measurements](audio-audit-v2.json) ·
[Spectrum and waveform plot](audio-audit-v2.png)

## Continuity and recovery review

| Event or failure source | Build 2 behavior and remaining limit |
|---|---|
| Ordinary playback, lock, background, return to app | Keeps the existing engine and filter state. No timer, file loop, queue refill, network fetch, or background transition stops it. Simulator background test observed at least 14 seconds of source-clock progress during a 15-second background interval, with no extra engine start. |
| Render deadline pressure | C callback allocates nothing, takes no locks, does no I/O, and uses no main-thread task. Commands and diagnostic counters use compile-time-verified lock-free atomics. Real device scheduling, thermal and battery behavior still need an overnight run. |
| Random walk or DC drift | Stable finite-pole filters and bounded excitation; no unbounded accumulated random walk. Filter state persists across callbacks. |
| Callback boundaries / channels | Identical output when rendering the same sequence in arbitrary chunk sizes. Interleaved stereo duplication and surrounding memory canaries pass. |
| Open / resume | 750 ms startup fade; no healthy-engine restart on repeated foreground or route notifications. |
| Explicit pause / quick Play | 80 ms render-thread fade before stopping. Quick Play cancels the pending stop and reverses the fade from its current level over 250 ms, preserving engine and source clock. Real-engine simulator tests pass. |
| Call, Siri, other non-mixing audio | OS can interrupt. Stop promptly; automatically resume only if iOS supplies permission and the user has not paused. No app can promise zero gap here. |
| Missing interruption-ended event | Explicit app/lock-screen Play clears the stale interruption state and attempts activation again. If audio remains unavailable, retries back off. |
| Headphone / Bluetooth disconnect | Opt out of iOS's default Now Playing disconnect interruption. Continue on the available route, potentially the speaker. A physical route change can still cause a system gap. |
| Sample-rate / engine configuration change | Default mixer-to-output connection tracks the route. Restart only a stopped engine, preserve generator state, fade in. Never destroy the engine synchronously from its configuration-notification queue. |
| Temporary route/activation failure | Retries after 0.25, 0.5, 1, 2, 4, 8, 15, then 30 seconds, repeating at 30 seconds while recovery remains appropriate. The previous retry sequence ended permanently after about 15 seconds. There is no recovery timer during healthy playback. iOS background scheduling is still system-controlled. |
| Media services lost/reset | Do not attempt activation while lost, including after late notifications. Rebuild objects and session preferences after reset. Apple requires a user action to restart; the UI asks for a tap. |
| Stop from lock-screen controls | Respects user intent and prevents interruption recovery from undoing the pause. Reopening the app intentionally starts playback again, matching the requested app behavior. |
| Control Center / Siri closes while app stays foregrounded | Build 3 does not treat temporary inactivity as an app reopen. It preserves a pause or an interruption's denied-resume state. |
| Force quit, OS termination/crash, reboot, empty battery, disconnected/powered-off speaker | Sound stops. The app cannot override these events. |
| Other sounds / output processing | Mixing prevents avoidable exclusivity, but does not suppress alarms, notification sounds, or another app's output. System volume, EQ, speaker protection, Bluetooth and AirPlay processing remain outside the generator. |

## Evidence and reproduction

Production files: `Sources/BrownNoiseDSP/BrownNoiseDSP.c`, `BNColorFilter.h`,
`Sources/PlaybackCore/PlaybackController.swift`, `App/NoiseAudioDriver.swift`,
and `App/AudioService.swift`. Audit outputs and Xcode results are under
`build/audio-audit-v2/`. Original build-1 source and samples were preserved there.
Final build-3 integration/UI results, archive and distribution logs are under
`build/release-v3/`; no signal regeneration was needed for that lifecycle-only change.

```sh
swift test
mkdir -p build/audio-audit-v2
xcrun clang -O3 -Wall -Wextra -Werror -I Sources/BrownNoiseDSP/include \
  Sources/BrownNoiseDSP/BrownNoiseDSP.c scripts/audio-check.c \
  -o build/audio-audit-v2/audio-check
build/audio-audit-v2/audio-check 48
build/audio-audit-v2/audio-check --sample build/audio-audit-v2/v2.f32
xcrun clang -O3 -Wall -Wextra -Werror scripts/filter-audit.c \
  -o build/audio-audit-v2/filter-audit
build/audio-audit-v2/filter-audit
xcrun clang -O3 -I Sources/BrownNoiseDSP/include \
  -c Sources/BrownNoiseDSP/BrownNoiseDSP.c -o build/audio-audit-v2/BrownNoiseDSP.o
xcrun swiftc -swift-version 6 -O \
  -import-objc-header Sources/BrownNoiseDSP/include/BrownNoiseDSP.h \
  scripts/render-engine.swift build/audio-audit-v2/BrownNoiseDSP.o \
  -o build/audio-audit-v2/render-engine -framework AVFoundation
for rate in 48000 44100 16000; do
  build/audio-audit-v2/render-engine "$rate" 120 "build/audio-audit-v2/engine-$rate.wav"
done
build/audio-audit-v2/render-engine 48000 120 build/audio-audit-v2/engine-48000-mono.wav 1
uv run --with numpy --with scipy --with matplotlib \
  python scripts/check-spectrum.py build/audio-audit-v2
```

The spectrum audit includes the old signal comparison when `v1.f32` is present.
The 48-hour result is accelerated computation (11 seconds on this Mac), not
48 hours of locked iPhone playback. An intended-output listening comparison and
12+ hour physical locked-screen run, including Low Power Mode and route/call
events, remain the outstanding device checks.

## Apple references checked during this audit

- [Playback session and background audio](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)
- [Engine configuration changes](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/avaudioengineconfigurationchange)
- [Route-disconnect interruption preference](https://developer.apple.com/documentation/avfaudio/avaudiosession/setprefersinterruptiononroutedisconnect(_:))
- [System-alert interruption preference](https://developer.apple.com/documentation/avfaudio/avaudiosession/setprefersnointerruptionsfromsystemalerts(_:))
- [Interruption handling, including missing end notifications](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html)
- [Media-services reset and required user action](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification)
- [Mixing with other audio](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers)

Installed Xcode 26.2 SDK headers `AVAudioEngine.h`, `AVAudioSourceNode.h`, and
`AVAudioSession.h` also confirm the mixer connection's automatic format behavior,
real-time render constraints, and nonzero output-format requirement.
