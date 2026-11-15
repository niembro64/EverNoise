import SwiftUI

@main
struct EverNoiseTVApp: App {
    @State private var audio = AudioService()
    @State private var wasBackgrounded = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TVContentView(audio: audio)
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
        }
    }
}
