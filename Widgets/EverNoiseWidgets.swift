import SwiftUI
import WidgetKit

struct NoiseEntry: TimelineEntry {
    let date: Date
    let snapshot: PlaybackSnapshot
}

struct NoiseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NoiseEntry { .init(date: .now, snapshot: .init()) }
    func getSnapshot(in context: Context, completion: @escaping (NoiseEntry) -> Void) {
        completion(.init(date: .now, snapshot: context.isPreview ? .init() : PlaybackSnapshotStore().read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NoiseEntry>) -> Void) {
        // Event-driven updates, with a modest fallback for abnormal termination.
        // This is an OS-scheduled widget refresh, not a running app timer.
        completion(Timeline(entries: [.init(date: .now, snapshot: PlaybackSnapshotStore().read())],
                            policy: .after(.now.addingTimeInterval(900))))
    }
}

struct NoiseWidgetView: View {
    let entry: NoiseEntry
    @Environment(\.widgetFamily) private var family
    private var active: Bool { entry.snapshot.isPlaying && !entry.snapshot.isSilent }
    private var tint: Color { Color(red: 0.65, green: 0.72, blue: 0.92) }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                playbackButton(compact: true)
            case .accessoryRectangular:
                HStack(spacing: 10) {
                    playbackButton(compact: true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("EverNoise").font(.headline)
                        Text(entry.snapshot.isPlaying ? "Playing" : "Play your sound").font(.caption)
                    }
                }
            default:
                homeWidget
            }
        }
        .containerBackground(for: .widget) { Color(white: 0.035) }
        .foregroundStyle(.white)
        .widgetURL(URL(string: "evernoise://open"))
    }

    private var homeWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EverNoise").font(.custom("AvenirNext-UltraLight", size: 23, relativeTo: .title2))
                    .minimumScaleFactor(0.8).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "infinity").font(.title2).foregroundStyle(active ? tint : Color(white: 0.60))
                    .widgetAccentable()
            }
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                if family == .systemMedium {
                    VStack(alignment: .leading, spacing: 7) {
                        band("High", level: entry.snapshot.high, color: Color(red: 0.60, green: 0.68, blue: 0.90))
                        band("Mid", level: entry.snapshot.mid, color: Color(red: 0.60, green: 0.78, blue: 0.65))
                        band("Low", level: entry.snapshot.low, color: Color(red: 0.87, green: 0.57, blue: 0.60))
                    }
                    Spacer(minLength: 0)
                }
                playbackButton(compact: false)
                if family == .systemSmall { Spacer(minLength: 0) }
            }
            Spacer(minLength: 0)
            Text(entry.snapshot.caption).font(.caption).foregroundStyle(Color(white: 0.68)).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func playbackButton(compact: Bool) -> some View {
        Button(intent: ToggleNoiseIntent()) {
            Image(systemName: entry.snapshot.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: compact ? 20 : 25, weight: .medium))
                .frame(width: compact ? 44 : 56, height: compact ? 44 : 56)
                .background(.white.opacity(active ? 0.12 : 0.07), in: Circle())
                .foregroundStyle(active ? tint : Color(white: 0.88))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.snapshot.isPlaying ? "Pause EverNoise" : "Play EverNoise")
        .accessibilityHint("Uses your saved mix and App Loudness")
        .widgetAccentable()
    }

    private func band(_ title: String, level: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).foregroundStyle(Color(white: 0.68)).frame(width: 30, alignment: .leading)
            ForEach(1...5, id: \.self) { dot in
                Circle().fill(dot <= level ? (active ? color : Color.gray) : Color.gray.opacity(0.22))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(level == 0 ? "Off" : "\(level) of 5")
    }
}

struct EverNoisePlaybackWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: PlaybackSnapshotStore.widgetKind, provider: NoiseTimelineProvider()) { entry in
            NoiseWidgetView(entry: entry)
        }
        .configurationDisplayName("EverNoise")
        .description("Play or pause your saved sound without opening the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@available(iOS 18.0, *)
struct EverNoisePlaybackControl: ControlWidget {
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }
        func currentValue() async throws -> Bool { PlaybackSnapshotStore().read().isPlaying }
    }
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: PlaybackSnapshotStore.controlKind, provider: Provider()) { playing in
            ControlWidgetToggle("EverNoise", isOn: playing, action: SetNoisePlaybackIntent()) { isOn in
                Label(isOn ? "Playing" : "Paused", systemImage: "infinity")
            }
            .tint(.blue)
        }
        .displayName("EverNoise")
        .description("Play or pause your saved noise mix.")
    }
}

@main
struct EverNoiseWidgets: WidgetBundle {
    var body: some Widget {
        EverNoisePlaybackWidget()
        if #available(iOS 18.0, *) { EverNoisePlaybackControl() }
    }
}

#Preview(as: .systemSmall) { EverNoisePlaybackWidget() } timeline: {
    NoiseEntry(date: .now, snapshot: .init(status: .playing))
    NoiseEntry(date: .now, snapshot: .init())
}
#Preview(as: .systemMedium) { EverNoisePlaybackWidget() } timeline: {
    NoiseEntry(date: .now, snapshot: .init(status: .playing))
}
