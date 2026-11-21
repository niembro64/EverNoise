import AVKit
import SwiftUI

struct AudioOutputPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = false
        view.tintColor = UIColor(NoisePalette.accent)
        view.activeTintColor = UIColor(NoisePalette.accent)
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

struct SystemControlsGuide: View {
    var body: some View {
        List {
            Section("Home Screen & StandBy") {
                Text("Touch and hold your Home Screen, choose Edit, then Add Widget, and search for EverNoise. Choose a small or medium widget. Tap its play or pause button to control your saved sound without opening the app.")
                Text("You can also add the small widget to StandBy while your iPhone charges on its side.")
            }
            Section("Lock Screen") {
                Text("Touch and hold the Lock Screen, choose Customize, then Add Widgets and EverNoise. Its play or pause button controls your sound even while another app is playing audio. iOS decides which app appears in its separate Now Playing media card.")
            }
            if #available(iOS 18.0, *) {
                Section("Control Center & Action button") {
                    Text("Open Control Center, touch and hold, choose Add a Control, and search for EverNoise. The same control can replace a Lock Screen shortcut. On supported iPhones, choose Controls → EverNoise in Settings → Action Button.")
                }
            }
            Section("Siri & Shortcuts") {
                Text("Say “Siri, start EverNoise” or “Siri, pause EverNoise.” In Shortcuts, search for EverNoise to add Start, Pause, or Play or Pause to a bedtime automation or your Action button.")
            }
            Section {
                Text("Every control uses your saved mix and App Loudness on this device. Widgets stay still to save power. Opening EverNoise starts playback; a widget’s play or pause button works in the background. iOS may require an unlock after restarting your device.")
            }
        }
        .font(AppTypography.body)
        .navigationTitle("Widgets & shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
