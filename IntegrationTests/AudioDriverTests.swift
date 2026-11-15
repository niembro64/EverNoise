import AVFoundation
import XCTest
import PlaybackCore
@testable import JustBrownNoise

@MainActor
final class AudioDriverTests: XCTestCase {
    func testStereoChangesKeepTheSameEngineAndClock() async throws {
        let driver = NoiseAudioDriver(mix: NoiseMix(highs: 3, mids: 2))
        defer { driver.stop(immediately: true) }
        XCTAssertTrue(driver.stereoEnabled)
        try driver.start()
        let engine = driver.currentEngine, before = driver.renderedFrames
        for index in 0..<20 {
            driver.setStereoEnabled(index.isMultiple(of: 2))
            try await Task.sleep(for: .milliseconds(37))
            XCTAssertEqual(driver.stereoEnabled, index.isMultiple(of: 2))
            XCTAssertTrue(driver.currentEngine === engine && driver.isRunning)
            XCTAssertEqual(driver.startCount, 1)
        }
        XCTAssertGreaterThan(driver.renderedFrames, before + 4000)
    }

    func testStereoPreferenceSurvivesPauseAndEngineReset() throws {
        let driver = NoiseAudioDriver()
        defer { driver.stop(immediately: true) }
        driver.setStereoEnabled(true)
        XCTAssertFalse(driver.isRunning)
        try driver.start()
        driver.stop(immediately: true)
        driver.setStereoEnabled(false)
        XCTAssertFalse(driver.isRunning)
        XCTAssertEqual(driver.startCount, 1)
        driver.setStereoEnabled(true)
        driver.reset()
        XCTAssertTrue(driver.stereoEnabled)
        try driver.start()
        XCTAssertTrue(driver.stereoEnabled && driver.isRunning)
        XCTAssertEqual(driver.startCount, 2)
    }

    func testSoundChangesKeepTheSameEngineAndClock() async throws {
        let driver = NoiseAudioDriver()
        defer { driver.stop(immediately: true) }
        try driver.start()
        let engine = driver.currentEngine
        let before = driver.renderedFrames
        for index in 0..<125 {
            let mix = NoiseMix(highs: index % 5, mids: (index / 5) % 5, lows: index / 25)
            driver.select(mix)
            try await Task.sleep(for: .milliseconds(37))
            XCTAssertTrue(driver.isRunning)
            XCTAssertTrue(driver.currentEngine === engine)
            XCTAssertEqual(driver.startCount, 1)
            XCTAssertEqual(driver.selectedMix, mix)
        }
        XCTAssertGreaterThan(driver.renderedFrames, before + 4_000)
    }

    func testChangingSoundWhilePausedDoesNotStartAudio() throws {
        let driver = NoiseAudioDriver()
        defer { driver.stop(immediately: true) }
        try driver.start()
        driver.stop(immediately: true)
        driver.select(NoiseMix(highs: 4, mids: 0))
        driver.select(NoiseMix(highs: 2, mids: 3, lows: 1))
        XCTAssertFalse(driver.isRunning)
        XCTAssertEqual(driver.startCount, 1)
        try driver.start()
        XCTAssertEqual(driver.selectedMix, NoiseMix(highs: 2, mids: 3, lows: 1))
        XCTAssertTrue(driver.isRunning)
    }

    func testRapidPausePlayKeepsTheRunningEngineAndRenderClock() async throws {
        let driver = NoiseAudioDriver()
        defer { driver.stop(immediately: true) }
        try driver.start()
        try await Task.sleep(for: .milliseconds(500))
        let before = driver.renderedFrames
        let starts = driver.startCount
        driver.stop(immediately: false)
        try driver.start()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(driver.isRunning)
        XCTAssertEqual(driver.startCount, starts)
        XCTAssertGreaterThan(driver.renderedFrames, before + 2_000)
    }

    func testPauseStopsAfterFadeAndRestartPreservesSourceClock() async throws {
        let driver = NoiseAudioDriver()
        defer { driver.stop(immediately: true) }
        try driver.start()
        try await Task.sleep(for: .milliseconds(500))
        driver.stop(immediately: false)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertFalse(driver.currentEngine?.isRunning ?? false)
        let before = driver.renderedFrames
        try driver.start()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(driver.isRunning)
        XCTAssertGreaterThan(driver.renderedFrames, before + 2_000)
        XCTAssertEqual(driver.startCount, 2)
    }

    func testBackgroundSessionPreferencesAndImmediateSystemStop() throws {
        let driver = NoiseAudioDriver()
        defer { driver.stop(immediately: true) }
        try driver.start()
        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playback)
        XCTAssertTrue(session.categoryOptions.contains(.mixWithOthers))
        XCTAssertFalse(session.prefersInterruptionOnRouteDisconnect)
        driver.stop(immediately: true)
        XCTAssertFalse(driver.currentEngine?.isRunning ?? false)
    }
}
