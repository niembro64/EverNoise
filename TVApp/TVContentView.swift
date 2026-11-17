import PlaybackCore
import SwiftUI

struct TVContentView: View {
    let audio: AudioService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AnimationLevel.preferenceKey) private var animationLevel = AnimationLevel.initialPreference()
    @State private var showingSettings = false
    @FocusState private var focusedControl: Control?
    private enum Control: Hashable { case playback, settings }

    private var playing: Bool { audio.playback.state == .playing }
    private var sounding: Bool { playing && !audio.selectedMix.isSilent }
    private var animate: Bool { animationLevel.animatesInfinity && !reduceMotion }

    var body: some View {
        RibbonScene(palette: RibbonPalette(mix: audio.selectedMix), isSounding: sounding,
                    isVisible: scenePhase == .active && !showingSettings,
                    animationLevel: animationLevel) { frame in
            NoiseGlassGroup {
                HStack(spacing: 80) {
                    VStack(spacing: 20) {
                        Color.clear
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .anchorPreference(key: InfinityBounds.self, value: .bounds) { $0 }
                            .accessibilityHidden(true)
                        Text("EverNoise").font(AppTypography.title)
                        Text("Your sound. All night.")
                            .font(AppTypography.subtitle)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 28) {
                        band("Low", id: "low", level: audio.selectedMix.lows, hue: NoisePalette.low) {
                            audio.selectMix(NoiseMix(highs: audio.selectedMix.highs, mids: audio.selectedMix.mids, lows: $0))
                        }
                        band("Mid", id: "mid", level: audio.selectedMix.mids, hue: NoisePalette.mid) {
                            audio.selectMix(NoiseMix(highs: audio.selectedMix.highs, mids: $0, lows: audio.selectedMix.lows))
                        }
                        band("High", id: "high", level: audio.selectedMix.highs, hue: NoisePalette.high) {
                            audio.selectMix(NoiseMix(highs: $0, mids: audio.selectedMix.mids, lows: audio.selectedMix.lows))
                        }
                        HStack(spacing: 40) {
                            Button(action: togglePlayback) {
                                Image(systemName: playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 40))
                                    .frame(width: 112, height: 112)
                            }
                            .buttonStyle(NoiseGlassButtonStyle(shape: Circle(), interactive: animate, colorful: sounding))
                            .accessibilityLabel(playing ? "Pause sound" : "Play sound")
                            .accessibilityValue(playing ? "Playing continuously" : "Paused")
                            .accessibilityIdentifier("playbackButton")
                            .focused($focusedControl, equals: .playback)
                            Button { showingSettings = true } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 32))
                                    .frame(width: 96, height: 96)
                            }
                            .buttonStyle(NoiseGlassButtonStyle(shape: Circle(), interactive: animate, colorful: sounding))
                            .accessibilityLabel("Settings")
                            .accessibilityIdentifier("settingsButton")
                            .focused($focusedControl, equals: .settings)
                        }
                        .padding(.top, 16)
                        #if DEBUG
                        Text(audio.diagnostics)
                            .font(.system(size: 1))
                            .foregroundStyle(.black)
                            .accessibilityIdentifier("audioDiagnostics")
                        #endif
                        if case .unavailable(let message) = audio.playback.state {
                            Text(message).font(AppTypography.footnote)
                        }
                    }
                    .frame(maxWidth: 720)
                }
                .padding(80)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .backgroundPreferenceValue(InfinityBounds.self) { anchor in
                GeometryReader { geometry in
                    RibbonArtwork(frame: frame, infinityRect: anchor.map { geometry[$0] } ?? .zero)
                }
                .ignoresSafeArea()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .font(AppTypography.body)
        .defaultFocus($focusedControl, .playback)
        .onPlayPauseCommand(perform: togglePlayback)
        .sheet(isPresented: $showingSettings) { TVSettingsView(audio: audio) }
    }

    private func band(_ title: String, id: String, level: Int, hue: SIMD3<Double>, select: @escaping (Int) -> Void) -> some View {
        BandPicker(title: title, id: id, level: level, showsColor: sounding, animate: animate,
                   color: { NoisePalette.color(hue, intensity: $0) }, select: select)
    }

    private func togglePlayback() {
        if playing { audio.pause() } else { audio.play() }
    }
}

private struct TVSettingsView: View {
    let audio: AudioService
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AnimationLevel.preferenceKey) private var animationLevel = AnimationLevel.initialPreference()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VolumeOffsetControl(audio: audio)
                } footer: {
                    Text("Saved for every mix. Adjust EverNoise to sit comfortably alongside your other audio.")
                }
                Picker("Audio", selection: Binding(get: { audio.stereoEnabled }, set: { audio.setStereoEnabled($0) })) {
                    Text("Mono").tag(false)
                    Text("Stereo").tag(true)
                }
                Picker("Animations", selection: $animationLevel) {
                    ForEach(AnimationLevel.allCases) { Text($0.title).tag($0) }
                }
                Section("Playback") {
                    Text("Low, Mid, and High shape the balance of your sound. EverNoise gently maintains overall loudness. Turning every band off makes the mix silent.")
                    Text("Open EverNoise to start. Use your TV or receiver controls for volume. Sound continues when you switch apps. Press Play/Pause on your remote to pause or resume.")
                    Text("Turning off or putting Apple TV to sleep stops playback. Other apps and system events can interrupt audio.")
                }
                Section("Privacy and support") {
                    Text("All sound is generated on your device. No accounts, ads, purchases, tracking, or collected personal data.")
                    Text("niemo.io/evernoise")
                }
                Button("Done") { dismiss() }
            }
            .navigationTitle("Settings")
        }
        .font(AppTypography.body)
    }
}
