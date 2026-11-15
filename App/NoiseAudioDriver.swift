import AVFoundation
import BrownNoiseDSP
import PlaybackCore

/// The source node retains this storage until its final render is finished.
/// After construction, only the render callback touches the DSP state, except
/// for a fade reset while the engine is stopped.
private final class NoiseStream: @unchecked Sendable {
    let pointer: OpaquePointer
    let kind: BNSourceKind

    init(kind: BNSourceKind, level: Int, stereoEnabled: Bool) throws {
        self.kind = kind
        guard let pointer = BNStereoCreateSource(kind, UInt64.random(in: 1...UInt64.max),
                                               UInt64.random(in: 1...UInt64.max), stereoEnabled) else {
            throw CocoaError(.coderInvalidValue)
        }
        self.pointer = pointer
        BNStereoSetLevel(pointer, Int32(level))
        BNStereoBeginFadeIn(pointer)
    }

    deinit { BNStereoDestroy(pointer) }
}

private final class RenderStorage {
    // All streams keep their clocks/filter state, even while inaudible. Brown
    // keeps its original 8 kHz path; full-band sources render at 48 kHz.
    let streams: [NoiseStream]

    init(mix: NoiseMix, stereoEnabled: Bool) throws {
        streams = try [BNSourceBrown, BNSourceMid, BNSourceGrayAir].map { kind in
            try NoiseStream(kind: kind, level: Self.level(kind, in: mix), stereoEnabled: stereoEnabled)
        }
    }

    private static func level(_ kind: BNSourceKind, in mix: NoiseMix) -> Int {
        switch kind {
        case BNSourceBrown: mix.lows
        case BNSourceMid: mix.mids
        default: mix.highs
        }
    }

    func select(_ mix: NoiseMix) {
        // Every layer keeps its clock and filter state, even at level zero.
        for stream in streams {
            BNStereoSetLevel(stream.pointer, Int32(Self.level(stream.kind, in: mix)))
        }
    }
    func setStereoEnabled(_ enabled: Bool) {
        for stream in streams { BNStereoSetEnabled(stream.pointer, enabled) }
    }
    func setPlaying(_ playing: Bool) {
        for stream in streams { BNStereoSetPlaying(stream.pointer, playing) }
    }
    func beginFadeIn() { for stream in streams { BNStereoBeginFadeIn(stream.pointer) } }
    var isSilent: Bool { streams.allSatisfy { BNStereoIsSilent($0.pointer) } }
    var renderedFrames: UInt64 { BNStereoRenderedFrames(streams[0].pointer) }
}

@MainActor
final class NoiseAudioDriver: AudioDriver {
    private var engine: AVAudioEngine?
    private var renderStorage: RenderStorage?
    private var stopTask: Task<Void, Never>?
    private var sessionConfigured = false
    private(set) var selectedMix: NoiseMix
    private(set) var stereoEnabled: Bool
    private(set) var startCount = 0
    var renderedFrames: UInt64 { renderStorage?.renderedFrames ?? 0 }
    var isRunning: Bool { engine?.isRunning == true && stopTask == nil }
    var currentEngine: AVAudioEngine? { engine }

    init(mix: NoiseMix = .baseline, stereoEnabled: Bool = true) {
        selectedMix = mix
        self.stereoEnabled = stereoEnabled
    }

    func setStereoEnabled(_ enabled: Bool) {
        stereoEnabled = enabled
        renderStorage?.setStereoEnabled(enabled)
        // Both channels already exist. No graph/session changes or allocations.
    }

    func select(_ mix: NoiseMix) {
        selectedMix = mix
        renderStorage?.select(mix)
        // Selection never activates, stops, or rebuilds the audio engine.
    }

    func start() throws {
        stopTask?.cancel()
        stopTask = nil
        if engine?.isRunning == true {
            // Reverse a pending fade-out without stopping or resetting audio.
            renderStorage?.setPlaying(true)
            return
        }
        let session = AVAudioSession.sharedInstance()
        if !sessionConfigured {
            // Configure while inactive. Reapplying hardware preferences during
            // recovery can itself cause another route/configuration change.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? session.setPreferredSampleRate(48_000)
            try? session.setPreferredIOBufferDuration(0.023)
            try? session.setPrefersNoInterruptionsFromSystemAlerts(true)
            // iOS 17+ otherwise interrupts Now Playing apps on disconnect.
            // This app intentionally continues on the new output, even speaker.
            try session.setPrefersInterruptionOnRouteDisconnect(false)
            sessionConfigured = true
        }
        try session.setActive(true)

        do {
            if engine == nil { try makeEngine() }
            guard let engine else { throw CocoaError(.coderInvalidValue) }
            let hardware = engine.outputNode.outputFormat(forBus: 0)
            guard hardware.sampleRate > 0, hardware.channelCount > 0 else {
                throw CocoaError(.coderInvalidValue)
            }
            // Source rates stay fixed. The mixer's default output connection
            // tracks the hardware format on every restart.
            // Do not pin a mixer-to-output format: Apple updates it automatically.
            renderStorage?.beginFadeIn()
            engine.prepare()
            try engine.start()
            startCount += 1
        } catch {
            engine?.stop()
            engine = nil
            // Preserve the sequence/filter state across a failed activation.
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    func stop(immediately: Bool) {
        stopTask?.cancel()
        stopTask = nil
        guard !immediately, engine?.isRunning == true, let renderStorage else {
            stopNow()
            return
        }
        renderStorage.setPlaying(false)
        stopTask = Task { @MainActor [weak self] in
            do {
                // Give the 80 ms render-thread fade time to reach the output.
                try await Task.sleep(for: .milliseconds(120))
                for _ in 0..<10 {
                    guard let self, !Task.isCancelled else { return }
                    if renderStorage.isSilent || self.engine?.isRunning != true {
                        self.stopNow()
                        return
                    }
                    try await Task.sleep(for: .milliseconds(40))
                }
                // If rendering has stalled, don't retain a phantom session.
                guard !Task.isCancelled else { return }
                self?.stopNow()
            } catch { /* A new Play cancels this pending stop. */ }
        }
    }

    private func stopNow() {
        stopTask?.cancel()
        stopTask = nil
        engine?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func reset() {
        // Called asynchronously after the notification, never on the engine's
        // configuration callback queue, where disposal could deadlock.
        stopTask?.cancel()
        stopTask = nil
        engine?.stop()
        engine = nil
        renderStorage = nil
        sessionConfigured = false
    }

    private func makeEngine() throws {
        let storage = try renderStorage ?? RenderStorage(mix: selectedMix, stereoEnabled: stereoEnabled)
        let newEngine = AVAudioEngine()
        for stream in storage.streams {
            // Permanent stereo avoids any graph rebuild when the mode changes.
            // Duplicated mono has the original calibrated per-channel gain.
            // Unlike Apple's mono-input SRC, it does not add rate-dependent
            // attenuation (the old 44.1 kHz path was about 3 dB quieter).
            guard let format = AVAudioFormat(standardFormatWithSampleRate: BNRateForSource(stream.kind), channels: 2) else {
                throw CocoaError(.coderInvalidValue)
            }
            let source = AVAudioSourceNode(format: format) { @Sendable [stream] isSilence, _, count, buffers in
                isSilence.pointee = false
                BNStereoRenderAudioBuffers(stream.pointer, buffers, count)
                return noErr
            }
            newEngine.attach(source)
            newEngine.connect(source, to: newEngine.mainMixerNode, format: format)
        }
        renderStorage = storage
        engine = newEngine
    }

    deinit { stopTask?.cancel() }
}
