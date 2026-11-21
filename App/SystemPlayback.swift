#if os(iOS)
import AppIntents
import OSLog
import WidgetKit

@MainActor
final class SystemPlaybackPublisher {
    private let store = PlaybackSnapshotStore()
    private var previous: PlaybackSnapshot?

    func publish(_ snapshot: PlaybackSnapshot) {
        guard snapshot != previous else { return }
        do {
            try store.publish(snapshot)
            previous = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: PlaybackSnapshotStore.widgetKind)
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadControls(ofKind: PlaybackSnapshotStore.controlKind)
            }
        } catch {
            Logger(subsystem: "io.niemo.JustBrownNoise", category: "Widgets")
                .error("Could not publish playback state: \(error.localizedDescription)")
        }
    }
}

extension AudioService {
    func performSystemPlayback(_ playing: Bool) throws {
        if playing { play() } else { pause() }
        if playing && playback.state != .playing { throw PlaybackIntentError.unavailable }
    }

    func toggleSystemPlayback() throws {
        let shouldPause = playback.state == .playing || (playback.state == .interrupted && playback.wantsPlayback)
        try performSystemPlayback(!shouldPause)
    }
}

struct EverNoiseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PlayNoiseIntent(), phrases: ["Start \(.applicationName)", "Play \(.applicationName)"],
                    shortTitle: "Start noise", systemImageName: "play.fill")
        AppShortcut(intent: PauseNoiseIntent(), phrases: ["Pause \(.applicationName)", "Stop \(.applicationName)"],
                    shortTitle: "Pause noise", systemImageName: "pause.fill")
        AppShortcut(intent: ToggleNoiseIntent(), phrases: ["Toggle \(.applicationName)"],
                    shortTitle: "Play or pause", systemImageName: "playpause.fill")
    }
    static var shortcutTileColor: ShortcutTileColor { .blue }
}
#endif
