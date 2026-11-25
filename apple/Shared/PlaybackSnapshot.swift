import Foundation
import Darwin

/// Presentation only. Audio and preferences remain owned by the app process.
struct PlaybackSnapshot: Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        case playing, paused, interrupted, unavailable
    }
    var status: Status = .paused
    var low = 3
    var mid = 3
    var high = 2
    var isPlaying: Bool { status == .playing }
    var isSilent: Bool { low == 0 && mid == 0 && high == 0 }
    var caption: String {
        switch status {
        case .playing: isSilent ? "All bands off" : "Your sound. All night."
        case .paused: "Ready when you are."
        case .interrupted: "Audio interrupted"
        case .unavailable: "Tap to try again"
        }
    }
}

/// Only the app writes. A lifetime lock lets readers reject stale "playing"
/// data after a crash, force quit, or reboot, without polling or a heartbeat.
/// None of this code runs on the audio render thread.
final class PlaybackSnapshotStore {
    static let appGroup = "group.io.niemo.EverNoise"
    static let widgetKind = "EverNoise.Playback"
    static let controlKind = "EverNoise.PlaybackControl"

    static var sharedDirectory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    private let directory: URL?
    private var playbackLock: Int32 = -1

    init(directory: URL? = sharedDirectory) { self.directory = directory }

    func publish(_ snapshot: PlaybackSnapshot) throws {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if snapshot.isPlaying {
            if playbackLock == -1 {
                let fd = open(directory.appendingPathComponent("playback.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
                guard fd != -1 else { throw CocoaError(.fileWriteUnknown) }
                guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
                    close(fd)
                    throw CocoaError(.fileLocking)
                }
                playbackLock = fd
                // It contains no user data, and must remain readable when locked.
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                                     ofItemAtPath: directory.appendingPathComponent("playback.lock").path)
            }
        } else {
            releaseLock()
        }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: directory.appendingPathComponent("playback.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func read() -> PlaybackSnapshot {
        guard let directory,
              let data = try? Data(contentsOf: directory.appendingPathComponent("playback.json")),
              var snapshot = try? JSONDecoder().decode(PlaybackSnapshot.self, from: data) else { return .init() }
        if snapshot.isPlaying && !hasLivePlayback(in: directory) { snapshot.status = .paused }
        return snapshot
    }

    private func hasLivePlayback(in directory: URL) -> Bool {
        let fd = open(directory.appendingPathComponent("playback.lock").path, O_RDONLY)
        guard fd != -1 else { return false }
        defer { close(fd) }
        if flock(fd, LOCK_EX | LOCK_NB) == 0 {
            flock(fd, LOCK_UN)
            return false
        }
        return errno == EWOULDBLOCK
    }

    private func releaseLock() {
        if playbackLock != -1 { close(playbackLock); playbackLock = -1 }
    }

    deinit { releaseLock() }
}
