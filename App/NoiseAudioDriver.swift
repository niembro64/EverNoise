import AVFoundation
import BrownNoiseDSP
import PlaybackCore
import SpectrumAnalysis

/// The source node retains this storage until its final render is finished.
/// After construction, only the render callback touches the DSP state, except
/// for a fade reset while the engine is stopped.
private final class RenderStorage: @unchecked Sendable {
    let pointer: OpaquePointer

    init(mix: NoiseMix, stereoEnabled: Bool, volumeOffsetDB: Int) throws {
        guard let pointer = BNMixCreate(UInt64.random(in: 1...UInt64.max)) else {
            throw CocoaError(.coderInvalidValue)
        }
        self.pointer = pointer
        select(mix)
        setStereoEnabled(stereoEnabled)
        setVolumeOffsetDB(volumeOffsetDB)
        beginFadeIn()
    }

    deinit { BNMixDestroy(pointer) }
    func select(_ mix: NoiseMix) {
        BNMixSetLevels(pointer, Int32(mix.lows), Int32(mix.mids), Int32(mix.highs))
    }
    func setStereoEnabled(_ enabled: Bool) { BNMixSetStereo(pointer, enabled) }
    func setVolumeOffsetDB(_ value: Int) { BNMixSetOffsetDB(pointer, Int32(value)) }
    func setPlaying(_ playing: Bool) { BNMixSetPlaying(pointer, playing) }
    func beginFadeIn() { BNMixBeginFadeIn(pointer) }
    var isSilent: Bool { BNMixIsSilent(pointer) }
    var renderedFrames: UInt64 { BNMixRenderedFrames(pointer) }
}

@MainActor
final class NoiseAudioDriver: AudioDriver {
    private var engine: AVAudioEngine?
    private var renderStorage: RenderStorage?
    private var stopTask: Task<Void, Never>?
    private var sessionConfigured = false
    private(set) var selectedMix: NoiseMix
    private(set) var stereoEnabled: Bool
    private(set) var volumeOffsetDB: Int
    private(set) var startCount = 0
    var renderedFrames: UInt64 { renderStorage?.renderedFrames ?? 0 }
    var isRunning: Bool { engine?.isRunning == true && stopTask == nil }
    var currentEngine: AVAudioEngine? { engine }
    let outputSamples = OutputSampleFeed()

    init(mix: NoiseMix = .baseline, stereoEnabled: Bool = true, volumeOffsetDB: Int = 0) {
        selectedMix = mix
        self.stereoEnabled = stereoEnabled
        self.volumeOffsetDB = VolumeOffset.clamp(volumeOffsetDB)
    }

    func setVolumeOffsetDB(_ value: Int) {
        volumeOffsetDB = VolumeOffset.clamp(value)
        renderStorage?.setVolumeOffsetDB(volumeOffsetDB)
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
        let storage = try renderStorage ?? RenderStorage(mix: selectedMix, stereoEnabled: stereoEnabled,
                                                        volumeOffsetDB: volumeOffsetDB)
        let newEngine = AVAudioEngine()
        // One permanent stereo node lets all bands share normalization, linked
        // peak protection, and an atomic mix command before Apple conversion.
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2) else {
            throw CocoaError(.coderInvalidValue)
        }
        let feed = outputSamples
        let source = AVAudioSourceNode(format: format) { @Sendable [storage, feed] isSilence, _, count, buffers in
            isSilence.pointee = false
            BNMixRenderAudioBuffers(storage.pointer, buffers, count)
            // Observe the final generated PCM after normalization, protection,
            // lookahead and fades. No FFT, waits, allocations or graph changes.
            if let capture = feed.pointer { BNCaptureAudioBuffers(capture, buffers, count) }
            return noErr
        }
        newEngine.attach(source)
        newEngine.connect(source, to: newEngine.mainMixerNode, format: format)
        renderStorage = storage
        engine = newEngine
    }

    deinit { stopTask?.cancel() }
}
