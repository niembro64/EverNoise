import Foundation
import Observation

@MainActor
public protocol AudioDriver: AnyObject {
    var isRunning: Bool { get }
    func start() throws
    func stop(immediately: Bool)
    func reset()
}

/// Owns playback intent independently of the view and the app's scene phase.
/// Backgrounding is intentionally not a stop event.
@MainActor
@Observable
public final class PlaybackController {
    public enum State: Equatable {
        case idle, playing, paused, interrupted
        case unavailable(String)
    }

    public private(set) var state: State = .idle
    public private(set) var wantsPlayback = false
    @ObservationIgnored private let driver: any AudioDriver
    @ObservationIgnored private var interruptionActive = false
    @ObservationIgnored private var needsUserAction = false
    @ObservationIgnored private var mediaServicesAvailable = true

    public init(driver: any AudioDriver) { self.driver = driver }

    /// Opening or returning to the app starts playback, as does a remote Play.
    public func play() {
        wantsPlayback = true
        needsUserAction = false
        // An explicit Play must recover a stale interruption even if iOS never
        // delivered its ended event. Session activation still decides whether
        // audio is currently permitted (for example, during a phone call).
        guard mediaServicesAvailable else { return }
        interruptionActive = false
        startIfNeeded()
    }

    public func becameActive() {
        // iOS does not always deliver an interruption-ended notification.
        // A fresh foreground activation is also an explicit request to play.
        play()
    }

    public func pause() {
        wantsPlayback = false
        driver.stop(immediately: false)
        state = .paused
    }

    public func toggle() {
        if state == .playing || (state == .interrupted && wantsPlayback) {
            pause()
        } else {
            // After a denied resume or activation error, the visible action
            // is Play, even if the earlier intent was to keep playing.
            play()
        }
    }

    public func interruptionBegan() {
        interruptionActive = true
        driver.stop(immediately: true)
        if wantsPlayback { state = .interrupted }
    }

    public func interruptionEnded(shouldResume: Bool) {
        interruptionActive = false
        guard wantsPlayback else { return }
        guard shouldResume else {
            needsUserAction = true
            state = .paused
            return
        }
        guard !needsUserAction else { return }
        startIfNeeded()
    }

    public func configurationChanged() {
        guard wantsPlayback, !interruptionActive, !needsUserAction else { return }
        startIfNeeded()
    }

    public func mediaServicesLost() {
        mediaServicesAvailable = false
        interruptionActive = true
        needsUserAction = true
        state = .unavailable("Audio is temporarily unavailable.")
    }

    public func mediaServicesReset() {
        driver.reset()
        mediaServicesAvailable = true
        interruptionActive = false
        // Apple requires a user action after the media server resets.
        needsUserAction = true
        state = .unavailable("Audio was reset by iOS. Tap to resume.")
    }

    public var canRetry: Bool {
        guard case .unavailable = state else { return false }
        return wantsPlayback && !interruptionActive && !needsUserAction && mediaServicesAvailable
    }

    /// Only retries activation failures; never fights a pause or interruption.
    public func retryIfNeeded() {
        guard canRetry else { return }
        startIfNeeded()
    }

    private func startIfNeeded() {
        // A late route/interruption event must not reactivate a lost server.
        guard mediaServicesAvailable else { return }
        do {
            if !driver.isRunning { try driver.start() }
            state = .playing
        } catch {
            state = .unavailable("Couldn't start audio. Tap to try again.")
        }
    }
}
