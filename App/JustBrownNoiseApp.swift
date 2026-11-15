import SwiftUI

@main
struct JustBrownNoiseApp: App {
    @State private var audio = AudioService()
    @State private var wasBackgrounded = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(audio: audio)
                .preferredColorScheme(.dark)
                .task { audio.opened() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                wasBackgrounded = true
            } else if phase == .active && wasBackgrounded {
                wasBackgrounded = false
                audio.opened()
            }
            // An inactive -> active transition alone (Control Center / Siri)
            // is not reopening the app and must not undo a user's pause.
            // Never pause, tear down, or rebuild the engine on inactive/background.
        }
    }
}
