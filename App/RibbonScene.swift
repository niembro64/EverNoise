import QuartzCore
import SwiftUI

/// One clock and one smoothly changing palette drive every foreground and
/// background ribbon. The display never reads or schedules audio work.
struct RibbonScene<Content: View>: View {
    let palette: RibbonPalette
    let isSounding: Bool
    let isVisible: Bool
    let animationLevel: AnimationLevel
    @ViewBuilder let content: (FluidMotion.Frame) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var motion = FluidMotion(now: CACurrentMediaTime())
    @State private var settled = false

    private var inputs: Inputs {
        Inputs(palette: palette, sounding: isSounding, visible: isVisible,
               level: animationLevel, reduced: reduceMotion)
    }

    @ViewBuilder var body: some View {
        if animationLevel == .off {
            // No timeline, shader, settling task or display timer in Off.
            content(FluidMotion.Frame(phase: 0, activity: isSounding ? 1 : 0,
                                      color: palette.mixedColor, bandPower: palette.bandPower, ambience: 0))
        } else {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: !isVisible || !animationLevel.animatesArtwork ||
                                    (settled && (!isSounding || reduceMotion)))) { _ in
            content(motion.sample(at: CACurrentMediaTime()))
        }
        .task(id: inputs) {
            motion.update(color: palette.mixedColor, sounding: isSounding, visible: isVisible,
                          reduceMotion: reduceMotion, bandPower: palette.bandPower,
                          animationLevel: animationLevel, at: CACurrentMediaTime())
            settled = false
            guard isVisible && animationLevel.animatesArtwork else { return }
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            motion.settle(at: CACurrentMediaTime())
            settled = true
        }
        }
    }

    private struct Inputs: Equatable {
        let palette: RibbonPalette
        let sounding: Bool
        let visible: Bool
        let level: AnimationLevel
        let reduced: Bool
    }
}
