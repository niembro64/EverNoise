import AVFoundation
import MediaPlayer
import Observation
import PlaybackCore
import UIKit

@MainActor
@Observable
final class AudioService {
    let playback: PlaybackController
    private(set) var selectedMix: NoiseMix
    private(set) var stereoEnabled: Bool
    private let defaults: UserDefaults
    #if DEBUG
    private(set) var diagnostics = "0:0"
    #endif
    private let driver: NoiseAudioDriver
    private var observers: [NSObjectProtocol] = []
    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var recoveryTask: Task<Void, Never>?
    private var artwork: MPMediaItemArtwork?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let selected = NoiseMix.load(from: defaults)
        selectedMix = selected
        // Absence means the new default; an explicitly saved Off stays Off.
        let stereo = defaults.object(forKey: "stereoEnabled") == nil || defaults.bool(forKey: "stereoEnabled")
        stereoEnabled = stereo
        let driver = NoiseAudioDriver(mix: selected, stereoEnabled: stereo)
        self.driver = driver
        playback = PlaybackController(driver: driver)
        observeAudioEvents()
        configureRemoteControls()
    }

    func opened() {
        playback.becameActive()
        refresh()
    }

    func play() {
        playback.play()
        refresh()
    }

    func pause() {
        playback.pause()
        refresh()
    }

    func selectMix(_ mix: NoiseMix) {
        guard mix != selectedMix else { return }
        selectedMix = mix
        mix.save(to: defaults)
        driver.select(mix)
        refresh()
    }

    func setStereoEnabled(_ enabled: Bool) {
        guard enabled != stereoEnabled else { return }
        stereoEnabled = enabled
        defaults.set(enabled, forKey: "stereoEnabled")
        driver.setStereoEnabled(enabled)
        refresh()
    }

    private func observeAudioEvents() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber)?.uintValue ?? 0
            // Always enqueue: configuration callbacks may originate on an audio
            // thread. Never synchronously stop/deallocate an engine from there.
            Task { @MainActor [weak self] in
                guard let self, let type = type.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) else { return }
                switch type {
                case .began: self.playback.interruptionBegan()
                case .ended: self.playback.interruptionEnded(shouldResume: AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume))
                @unknown default: break
                }
                self.refresh()
            }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil) { [weak self] note in
            let changedEngineID = (note.object as? AVAudioEngine).map(ObjectIdentifier.init)
            Task { @MainActor [weak self] in
                guard let self, changedEngineID == self.driver.currentEngine.map(ObjectIdentifier.init) else { return }
                self.playback.configurationChanged()
                self.refresh()
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Continue on the new route, including the speaker after a
                // disconnect. Configuration-change handles a stopped engine.
                self?.playback.configurationChanged()
                self?.refresh()
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereLostNotification, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playback.mediaServicesLost()
                self?.refresh()
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playback.mediaServicesReset()
                self?.refresh()
            }
        })
    }

    private func configureRemoteControls() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.isEnabled = true
        commands.pauseCommand.isEnabled = true
        commands.togglePlayPauseCommand.isEnabled = true
        commands.stopCommand.isEnabled = true
        commands.nextTrackCommand.isEnabled = false
        commands.previousTrackCommand.isEnabled = false
        commands.changePlaybackPositionCommand.isEnabled = false
        commands.skipForwardCommand.isEnabled = false
        commands.skipBackwardCommand.isEnabled = false
        for (index, command) in [commands.playCommand, commands.pauseCommand, commands.togglePlayPauseCommand, commands.stopCommand].enumerated() {
            let target = command.addTarget { @Sendable [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if index == 0 {
                        self.play()
                    } else if index == 2 {
                        self.playback.toggle()
                        self.refresh()
                    } else {
                        self.pause()
                    }
                }
                return .success
            }
            commandTargets.append((command, target))
        }
    }

    private func refresh() {
        #if DEBUG
        diagnostics = "\(driver.startCount):\(driver.renderedFrames)"
        #endif
        if artwork == nil, let image = UIImage(named: "NowPlayingArtwork") {
            artwork = MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in image }
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "EverNoise",
            MPMediaItemPropertyArtist: selectedMix.summary,
            MPNowPlayingInfoPropertyIsLiveStream: true,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: playback.state == .playing ? 1.0 : 0.0
        ]
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        recoveryTask?.cancel()
        recoveryTask = nil
        if playback.canRetry {
            // Don't permanently abandon an output that takes longer than 15 s
            // to return. Back off while unavailable; no timer runs in playback.
            recoveryTask = Task { [weak self] in
                let delays = [0.25, 0.5, 1, 2, 4, 8, 15, 30]
                var attempt = 0
                while !Task.isCancelled {
                    let seconds = delays[min(attempt, delays.count - 1)]
                    do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                    guard let self, self.playback.canRetry else { return }
                    self.playback.retryIfNeeded()
                    if self.playback.state == .playing { self.refresh(); return }
                    attempt = min(attempt + 1, delays.count - 1)
                }
            }
        }
    }
}
