import PlaybackCore
import Testing

@MainActor
private final class FakeAudioDriver: AudioDriver {
    var isRunning = false
    var starts = 0
    var stops = 0
    var immediateStops = 0
    var resets = 0
    var failsToStart = false
    func start() throws {
        starts += 1
        if failsToStart { throw TestFailure.unavailable }
        isRunning = true
    }
    func stop(immediately: Bool) {
        stops += 1
        if immediately { immediateStops += 1 }
        isRunning = false
    }
    func reset() { resets += 1; isRunning = false }
    enum TestFailure: Error { case unavailable }
}

@MainActor
struct PlaybackTests {
    @Test func openingStartsAndReturningDoesNotRestartHealthyAudio() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.becameActive()
        #expect(player.state == .playing)
        for _ in 0..<100 { player.becameActive(); player.configurationChanged() }
        #expect(driver.starts == 1)
        #expect(driver.stops == 0)
    }

    @Test func interruptedPlaybackResumesWhenAllowed() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        player.interruptionBegan()
        #expect(player.state == .interrupted)
        player.configurationChanged()
        #expect(driver.starts == 1)
        player.interruptionEnded(shouldResume: true)
        #expect(driver.starts == 2)
        #expect(player.state == .playing)
    }

    @Test func remotePauseDuringCallPreventsAutomaticRestart() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        player.interruptionBegan()
        player.pause()
        player.interruptionEnded(shouldResume: true)
        player.configurationChanged()
        player.retryIfNeeded()
        #expect(player.state == .paused)
        #expect(driver.starts == 1)
    }

    @Test func deniedResumeRequiresExplicitActionEvenAfterRouteChanges() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        player.interruptionBegan()
        player.interruptionEnded(shouldResume: false)
        player.configurationChanged()
        player.retryIfNeeded()
        #expect(driver.starts == 1)
        player.becameActive()
        #expect(driver.starts == 2)
    }

    @Test func stoppedEngineRecoversAfterRouteChangeWithoutRestartingRunningEngine() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        driver.isRunning = false
        player.configurationChanged()
        #expect(player.state == .playing)
        #expect(driver.starts == 2)
        player.configurationChanged()
        #expect(driver.starts == 2)
    }

    @Test func mediaResetRebuildsButWaitsForUserAction() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        player.mediaServicesLost()
        player.retryIfNeeded()
        #expect(driver.starts == 1)
        player.mediaServicesReset()
        player.configurationChanged()
        player.retryIfNeeded()
        #expect(driver.resets == 1)
        #expect(driver.starts == 1)
        player.play()
        #expect(player.state == .playing)
        #expect(driver.starts == 2)
    }

    @Test func transientFailureRetriesButPauseCancelsIntent() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        driver.failsToStart = true
        player.play()
        if case .unavailable = player.state {} else { Issue.record("Expected failure state") }
        driver.failsToStart = false
        player.retryIfNeeded()
        #expect(player.state == .playing)
        player.pause()
        player.retryIfNeeded()
        player.configurationChanged()
        #expect(driver.starts == 2)
    }

    @Test func foregroundRecoversAnInterruptionWithoutAnEndNotification() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        player.interruptionBegan()
        player.becameActive()
        #expect(player.state == .playing)
        #expect(driver.starts == 2)
    }

    @Test func remotePlayRecoversAnInterruptionWithoutAnEndNotification() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        player.interruptionBegan()
        player.play()
        #expect(player.state == .playing)
        #expect(driver.starts == 2)
    }

    @Test func remoteToggleResumesAfterDeniedAutomaticResume() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        player.interruptionBegan()
        player.interruptionEnded(shouldResume: false)
        player.toggle()
        #expect(player.state == .playing)
        #expect(driver.starts == 2)
    }

    @Test func remoteToggleDuringInterruptionCancelsResumeIntent() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        player.interruptionBegan()
        player.toggle()
        player.interruptionEnded(shouldResume: true)
        #expect(player.state == .paused)
        #expect(!player.wantsPlayback)
        #expect(driver.starts == 1)
    }

    @Test func explicitPauseFadesButSystemInterruptionStopsImmediately() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        player.pause()
        #expect(driver.stops == 1 && driver.immediateStops == 0)
        player.play()
        player.interruptionBegan()
        #expect(driver.immediateStops == 1)
    }

    @Test func lostMediaServerCannotRestartUntilResetAndUserAction() {
        let driver = FakeAudioDriver()
        let player = PlaybackController(driver: driver)
        player.play()
        player.mediaServicesLost()
        player.play()
        player.becameActive()
        player.interruptionEnded(shouldResume: true)
        player.configurationChanged()
        #expect(driver.starts == 1)
        #expect(!player.canRetry)
        player.mediaServicesReset()
        #expect(!player.canRetry)
        player.play()
        #expect(driver.starts == 2)
    }
}
