import SwiftUI

struct PrivacyView: View {
    let audio: AudioService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AnimationLevel.preferenceKey) private var animationLevel = AnimationLevel.initialPreference()
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Audio")
                        Picker("Audio", selection: Binding(get: { audio.stereoEnabled }, set: { audio.setStereoEnabled($0) })) {
                            Text("Mono").tag(false)
                            Text("Stereo").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .accessibilityIdentifier("audioModePicker")
                    }
                } footer: {
                    Text("Mono sends the same sound to both ears. Stereo creates independent sound in each ear and is the default.")
                        .font(AppTypography.footnote)
                }
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Animations")
                        Picker("Animations", selection: $animationLevel) {
                            ForEach(AnimationLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .accessibilityIdentifier("animationLevelPicker")
                    }
                } footer: {
                    Text("Low: still infinity. Med: flowing infinity. High: flowing infinity and ribbons. Med is the default. Your sound keeps playing.")
                        .font(AppTypography.footnote)
                }
                Section {
                    Text("EverNoise generates all sound on your device. It does not collect, store, or share personal data. There are no accounts, ads, analytics, tracking, or third-party services in the app.")
                    Text("The app works entirely offline. Opening an external support or privacy page uses your browser and is subject to that website’s privacy practices.")
                    Link(destination: URL(string: "https://niemo.io/evernoise/privacy.html")!) {
                        Text("Privacy policy").padding(.vertical, 8).padding(.horizontal, 16)
                    }
                        .buttonStyle(NoiseGlassButtonStyle(shape: Capsule(), interactive: animationLevel.animatesInfinity))
                } header: { Text("Your privacy").font(AppTypography.heading) }
                Section {
                    Text("Open the app to start. Use your device’s volume buttons, then lock your screen or switch apps. Playback has no time limit. Tap Pause on the main screen or in Control Center to stop. Opening the app starts it again.")
                    Text("Tap a button in each Low, Mid, and High row. The hollow circle is Off; four growing dots choose the intensity. A glass rim shows your selection. The four active levels keep the same equal 6 dB steps. New installations start on the third Low button, third Mid button, and second High button, counting Off as first. Changes fade smoothly, and the app remembers your choices. Turning every band off makes the mix silent.")
                    Text("Low uses muted rose, Mid uses sage, and High uses periwinkle. The large infinity mixes their color with six rainbow currents weighted by your bands’ power. Med animates the infinity on a black background. High adds four enormous, faint floating ribbons with the same liquid and mist. Low keeps a still infinity on black. Pausing or turning all bands off mutes the colors. Animation stops when hidden and respects Reduce Motion. Your animation level is remembered.")
                    Text("Stereo creates independent left and right signals with the same sound mix. Switching modes fades smoothly without restarting playback. Stereo starts on unless you have saved a different choice. A mono output cannot reproduce the stereo separation.")
                    Text("iOS can interrupt audio for calls, Siri, or system events. Playback resumes automatically when iOS permits. If audio is reset by iOS, tap Play to resume. Force-quitting the app or powering off the device stops playback.")
                    Text("If headphones disconnect, playback continues on the available output, which may be the speaker.")
                    Link(destination: URL(string: "https://niemo.io/evernoise/")!) {
                        Text("Get support").padding(.vertical, 8).padding(.horizontal, 16)
                    }
                        .buttonStyle(NoiseGlassButtonStyle(shape: Capsule(), interactive: animationLevel.animatesInfinity))
                } header: { Text("Using the app").font(AppTypography.heading) }
                Section { Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") · Made by Eric Niemeyer") }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Settings").font(AppTypography.heading) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(AppTypography.heading)
                }
            }
        }
        .font(AppTypography.body)
        .preferredColorScheme(.dark)
    }
}
