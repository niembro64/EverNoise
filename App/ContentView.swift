import PlaybackCore
import SwiftUI

struct ContentView: View {
    let audio: AudioService
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AnimationLevel.preferenceKey) private var animationLevel = AnimationLevel.initialPreference()
    @State private var showingSettings = false
    private let ink = Color(white: 0.88)
    private let muted = Color(white: 0.55)

    private var isPlaying: Bool { audio.playback.state == .playing }
    private var isSounding: Bool { isPlaying && !audio.selectedMix.isSilent }
    private var animateControls: Bool { animationLevel.animatesInfinity && !reduceMotion }
    private var status: String {
        switch audio.playback.state {
        case .idle: "Starting…"
        case .playing: audio.selectedMix.isSilent ? "All bands off" : "Playing continuously"
        case .paused: "Paused"
        case .interrupted: "Waiting for other audio to finish"
        case .unavailable(let message): message
        }
    }

    var body: some View {
        RibbonScene(palette: RibbonPalette(mix: audio.selectedMix), isSounding: isSounding,
                    isVisible: scenePhase == .active && !showingSettings,
                    animationLevel: animationLevel) { frame in
            NoiseGlassGroup { controls(frame: frame) }
                .backgroundPreferenceValue(InfinityBounds.self) { anchor in
                    GeometryReader { geometry in
                        RibbonArtwork(frame: frame, infinityRect: anchor.map { geometry[$0] } ?? .zero)
                    }
                    .ignoresSafeArea()
                }
        }
        .background(Color.black.ignoresSafeArea())
        .font(AppTypography.body)
        .sheet(isPresented: $showingSettings) { PrivacyView(audio: audio).tint(NoisePalette.accent) }
    }

    private func controls(frame: FluidMotion.Frame) -> some View {
        GeometryReader { geometry in
            let infinityWidth = max(1, min(geometry.size.width - 48, geometry.size.height * 0.82))
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(width: infinityWidth, height: infinityWidth * 9 / 16)
                        .anchorPreference(key: InfinityBounds.self, value: .bounds) { $0 }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Noise color")
                        .accessibilityValue(audio.selectedMix.summary)
                        .accessibilityIdentifier("noiseColor")
                        .padding(.bottom, 6)
                    Text("EverNoise")
                        .font(AppTypography.title)
                        .tracking(0.7)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ink)
                        .accessibilityIdentifier("noiseTitle")
                    Text("Your sound. All night.")
                        .font(AppTypography.subtitle)
                        .foregroundStyle(muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .padding(.bottom, 16)

                    VStack(spacing: 12) {
                        BandPicker(title: "Low", id: "low", level: audio.selectedMix.lows, showsColor: isSounding, animate: animateControls,
                                   color: { NoisePalette.color(NoisePalette.low, intensity: $0) }) { value in
                            audio.selectMix(NoiseMix(highs: audio.selectedMix.highs, mids: audio.selectedMix.mids, lows: value))
                        }
                        BandPicker(title: "Mid", id: "mid", level: audio.selectedMix.mids, showsColor: isSounding, animate: animateControls,
                                   color: { NoisePalette.color(NoisePalette.mid, intensity: $0) }) { value in
                            audio.selectMix(NoiseMix(highs: audio.selectedMix.highs, mids: value, lows: audio.selectedMix.lows))
                        }
                        BandPicker(title: "High", id: "high", level: audio.selectedMix.highs, showsColor: isSounding, animate: animateControls,
                                   color: { NoisePalette.color(NoisePalette.high, intensity: $0) }) { value in
                            audio.selectMix(NoiseMix(highs: value, mids: audio.selectedMix.mids, lows: audio.selectedMix.lows))
                        }
                    }
                    .frame(maxWidth: 420)

                    #if DEBUG
                    Text(audio.diagnostics)
                        .font(.system(size: 1))
                        .foregroundStyle(.black)
                        .accessibilityIdentifier("audioDiagnostics")
                    #endif

                    Button {
                        if isPlaying { audio.pause() } else { audio.play() }
                    } label: {
                        ZStack {
                            Image(systemName: "pause.fill").opacity(isPlaying ? 1 : 0)
                            Image(systemName: "play.fill").opacity(isPlaying ? 0 : 1)
                        }
                            .animation(animateControls ? .easeInOut(duration: 0.7) : nil, value: isPlaying)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(ink)
                            .frame(width: 112, height: 112)
                            .contentShape(Circle())
                    }
                    .buttonStyle(NoiseGlassButtonStyle(shape: Circle(), interactive: animateControls, colorful: isSounding))
                    .contentShape(Circle())
                    .accessibilityLabel(isPlaying ? "Pause sound" : "Play sound")
                    .accessibilityValue(status)
                    .accessibilityIdentifier("playbackButton")
                    .padding(.top, 18)

                    if case .unavailable(let message) = audio.playback.state {
                        Text(message)
                            .font(AppTypography.body)
                            .foregroundStyle(muted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .topTrailing) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22))
                        .foregroundStyle(muted)
                        .frame(width: 80, height: 80)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NoiseGlassButtonStyle(shape: Circle().inset(by: 18), interactive: animateControls, colorful: isSounding))
                .contentShape(Rectangle())
                .accessibilityLabel("Settings, privacy and support")
                .accessibilityIdentifier("settingsButton")
            }
        }
    }
}

#Preview { ContentView(audio: AudioService()).preferredColorScheme(.dark) }
