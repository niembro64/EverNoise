import AppIntents

// These types belong to BOTH targets. AudioPlaybackIntent routes execution to
// the containing app, including a cold background launch. The extension must
// never link an audio engine or silently pretend that it performed an action.
enum PlaybackIntentError: Error, CustomLocalizedStringResourceConvertible {
    case appRequired, unavailable
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .appRequired: "Open EverNoise to control playback."
        case .unavailable: "Audio is temporarily unavailable. Open EverNoise to try again."
        }
    }
}

struct PlayNoiseIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource { "Start EverNoise" }
    static var description: IntentDescription { "Play your saved mix and App Loudness continuously." }
    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    @MainActor func perform() async throws -> some IntentResult {
        #if WIDGET_EXTENSION
        try requireAppProcess()
        #else
        try AudioService.shared.performSystemPlayback(true)
        #endif
        return .result()
    }
}

struct PauseNoiseIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource { "Pause EverNoise" }
    static var description: IntentDescription { "Fade out and stop EverNoise. Your mix is remembered." }
    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    @MainActor func perform() async throws -> some IntentResult {
        #if WIDGET_EXTENSION
        try requireAppProcess()
        #else
        try AudioService.shared.performSystemPlayback(false)
        #endif
        return .result()
    }
}

struct ToggleNoiseIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource { "Play or Pause EverNoise" }
    static var description: IntentDescription { "Toggle EverNoise using its current playback state." }
    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    @MainActor func perform() async throws -> some IntentResult {
        #if WIDGET_EXTENSION
        try requireAppProcess()
        #else
        try AudioService.shared.toggleSystemPlayback()
        #endif
        return .result()
    }
}

@available(iOS 18.0, *)
struct SetNoisePlaybackIntent: AudioPlaybackIntent, SetValueIntent {
    static var title: LocalizedStringResource { "EverNoise Playback" }
    static var openAppWhenRun: Bool { false }
    static var isDiscoverable: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @Parameter(title: "Playing") var value: Bool

    @MainActor func perform() async throws -> some IntentResult {
        #if WIDGET_EXTENSION
        try requireAppProcess()
        #else
        try AudioService.shared.performSystemPlayback(value)
        #endif
        return .result()
    }
}

#if WIDGET_EXTENSION
private func requireAppProcess() throws {
    throw PlaybackIntentError.appRequired
}
#endif
