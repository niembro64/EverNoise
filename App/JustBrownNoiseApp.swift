import SwiftUI

@main
struct JustBrownNoiseApp: App {
    @State private var audio = AudioService.shared
    @State private var hasActivated = false
    @State private var wasBackgrounded = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(audio: audio)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .background {
                wasBackgrounded = true
            } else if phase == .active && (!hasActivated || wasBackgrounded) {
                hasActivated = true
                wasBackgrounded = false
                audio.opened()
            }
            // An inactive -> active transition alone (Control Center / Siri)
            // is not reopening the app and must not undo a user's pause.
            // Never pause, tear down, or rebuild the engine on inactive/background.
        }
    }
}
