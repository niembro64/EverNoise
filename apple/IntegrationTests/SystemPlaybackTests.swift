import AppIntents
import MediaPlayer
import PlaybackCore
import XCTest
@testable import JustBrownNoise

final class PlaybackSnapshotTests: XCTestCase {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }

    func testReaderRejectsPlayingSnapshotWhenWriterDies() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reader = PlaybackSnapshotStore(directory: directory)
        XCTAssertFalse(reader.read().isPlaying)
        var writer: PlaybackSnapshotStore? = PlaybackSnapshotStore(directory: directory)
        let playing = PlaybackSnapshot(status: .playing, low: 1, mid: 0, high: 5)
        try writer!.publish(playing)
        XCTAssertEqual(reader.read(), playing)
        writer = nil // The kernel also closes this lock after termination.
        XCTAssertEqual(reader.read(), PlaybackSnapshot(status: .paused, low: 1, mid: 0, high: 5))
    }

    func testPauseInterruptionAndResumePublishWithoutHeartbeats() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = PlaybackSnapshotStore(directory: directory)
        let reader = PlaybackSnapshotStore(directory: directory)
        for status in [PlaybackSnapshot.Status.paused, .playing, .interrupted, .playing, .unavailable, .paused] {
            let value = PlaybackSnapshot(status: status, low: 0, mid: 0, high: 0)
            try writer.publish(value)
            XCTAssertEqual(reader.read(), value)
            XCTAssertTrue(reader.read().isSilent)
        }
    }

    func testMissingAndCorruptStateAreSafePausedDefaults() throws {
        XCTAssertFalse(PlaybackSnapshotStore(directory: nil).read().isPlaying)
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("incomplete".utf8).write(to: directory.appendingPathComponent("playback.json"))
        XCTAssertEqual(PlaybackSnapshotStore(directory: directory).read(), .init())
    }
}

@MainActor
final class SystemPlaybackTests: XCTestCase {
    func testColdPauseDoesNotClaimNowPlayingOrStartAudio() throws {
        let service = AudioService()
        let center = MPNowPlayingInfoCenter.default()
        let previous = center.nowPlayingInfo
        defer { center.nowPlayingInfo = previous }
        center.nowPlayingInfo = [MPMediaItemPropertyTitle: "Other audio"]
        try service.performSystemPlayback(false)
        XCTAssertEqual(service.playback.state, .paused)
        XCTAssertEqual(service.diagnostics, "0:0")
        XCTAssertEqual(center.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "Other audio")
    }

    func testIntentsUseOneEngineAndPreserveSavedMixAndLoudness() async throws {
        let service = AudioService.shared
        let mix = service.selectedMix
        let offset = service.volumeOffsetDB
        let stereo = service.stereoEnabled
        defer {
            service.pause()
            service.selectMix(mix)
            service.setVolumeOffsetDB(offset)
            service.setStereoEnabled(stereo)
        }
        _ = try await PauseNoiseIntent().perform()
        try await Task.sleep(for: .milliseconds(650))
        service.selectMix(NoiseMix(highs: 1, mids: 2, lows: 4))
        service.setVolumeOffsetDB(-6)
        service.setStereoEnabled(false)
        _ = try await PlayNoiseIntent().perform()
        XCTAssertEqual(service.playback.state, .playing)
        let count = service.diagnostics.split(separator: ":").first
        try await Task.sleep(for: .milliseconds(250))
        _ = try await PlayNoiseIntent().perform()
        XCTAssertEqual(service.diagnostics.split(separator: ":").first, count, "An idempotent Play must not rebuild audio")
        XCTAssertEqual(service.selectedMix, NoiseMix(highs: 1, mids: 2, lows: 4))
        XCTAssertEqual(service.volumeOffsetDB, -6)
        XCTAssertFalse(service.stereoEnabled)
        XCTAssertTrue(PlaybackSnapshotStore().read().isPlaying)
        _ = try await ToggleNoiseIntent().perform()
        XCTAssertEqual(service.playback.state, .paused)
        XCTAssertFalse(PlaybackSnapshotStore().read().isPlaying)
        _ = try await ToggleNoiseIntent().perform()
        XCTAssertEqual(service.playback.state, .playing)
        if #available(iOS 18.0, *) {
            let set = SetNoisePlaybackIntent()
            set.value = false
            _ = try await set.perform()
            XCTAssertEqual(service.playback.state, .paused)
            set.value = true
            _ = try await set.perform()
            XCTAssertEqual(service.playback.state, .playing)
        }
        // Neither the shortcut nor the control changes an intentionally silent mix.
        service.selectMix(.init(highs: 0, mids: 0, lows: 0))
        _ = try await PlayNoiseIntent().perform()
        XCTAssertTrue(service.selectedMix.isSilent)
        XCTAssertTrue(PlaybackSnapshotStore().read().isSilent)
    }
}
