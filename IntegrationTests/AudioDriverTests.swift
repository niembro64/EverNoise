import AVFoundation
import XCTest
import PlaybackCore
#if os(tvOS)
@testable import EverNoiseTV
#else
@testable import JustBrownNoise
#endif

@MainActor
final class AudioDriverTests: XCTestCase {
    func testSpectrumCaptureStopsWithoutChangingPlayback() async throws {
        let driver = NoiseAudioDriver()
        defer { driver.outputSamples.stop(); driver.stop(immediately: true) }
        try driver.start()
        let original = driver.currentEngine
        XCTAssertEqual(driver.outputSamples.publishedFrames, 0)
        let lease = driver.outputSamples.begin()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertGreaterThan(driver.outputSamples.publishedFrames, 4000)
        driver.outputSamples.end(lease)
        try await Task.sleep(for: .milliseconds(80))
        let stopped = driver.outputSamples.publishedFrames, audio = driver.renderedFrames
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(driver.outputSamples.publishedFrames, stopped)
        XCTAssertGreaterThan(driver.renderedFrames, audio)
        XCTAssertTrue(driver.currentEngine === original)
        XCTAssertEqual(driver.startCount, 1)
    }

    func testVolumeOffsetDoesNotRestartAudioAndSurvivesReset() async throws {
        let driver = NoiseAudioDriver(volumeOffsetDB: -6)
        defer { driver.stop(immediately: true) }
        try driver.start()
        let engine = driver.currentEngine, frames = driver.renderedFrames
        for value in [-18, 3, -6, 0] {
            driver.setVolumeOffsetDB(value)
            try await Task.sleep(for: .milliseconds(80))
            XCTAssertEqual(driver.volumeOffsetDB, value)
            XCTAssertTrue(driver.currentEngine === engine && driver.isRunning)
            XCTAssertEqual(driver.startCount, 1)
        }
        XCTAssertGreaterThan(driver.renderedFrames, frames)
        driver.stop(immediately: true)
        driver.setVolumeOffsetDB(-7)
        driver.reset()
        XCTAssertFalse(driver.isRunning)
        try driver.start()
        XCTAssertEqual(driver.volumeOffsetDB, -7)
    }

    func testProductionBandsShareTheComplementary48kHzPath() throws {
        let driver = NoiseAudioDriver()
        defer { driver.stop(immediately: true) }
        try driver.start()
        let sources = try XCTUnwrap(driver.currentEngine).attachedNodes.compactMap { $0 as? AVAudioSourceNode }
        XCTAssertEqual(sources.count, 1, "All three bands share one normalized, peak-protected output")
        for source in sources {
            XCTAssertEqual(source.outputFormat(forBus: 0).sampleRate, 48000)
            XCTAssertEqual(source.outputFormat(forBus: 0).channelCount, 2)
        }
    }

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
