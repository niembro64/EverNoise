import SwiftUI

/// One native material for every app button, preserving our exact hit areas.
/// Glass is kept outside the offscreen artwork so it can sample the live scene.
struct NoiseGlassButtonStyle<S: Shape>: ButtonStyle {
    var tint: Color? = nil
    var shape: S
    var interactive = true
    var colorful = true
    var usesClearGlass = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(tvOS)
    @Environment(\.isFocused) private var isFocused
    #endif

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if #available(iOS 26.0, tvOS 26.0, macOS 26.0, visionOS 26.0, *) {
                configuration.label
                    .glassEffect((usesClearGlass ? Glass.clear : Glass.regular).tint(tint).interactive(interactive && !reduceMotion), in: shape)
            } else {
                configuration.label
                    .background(.ultraThinMaterial, in: shape)
                    .background(tint?.opacity(0.35) ?? .clear, in: shape)
                    .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 1))
                    .opacity(configuration.isPressed ? 0.8 : 1)
            }
        }
        // Native glass can add subtle chromatic highlights even to gray tint.
        // Explicitly drain those as well when the sound is paused or all off.
        .saturation(colorful ? 1 : 0)
        .animation(interactive && !reduceMotion ? .easeInOut(duration: 1.4) : nil, value: colorful)
        #if os(tvOS)
        .overlay(shape.stroke(.white.opacity(isFocused ? 0.9 : 0), lineWidth: 3))
        .scaleEffect(isFocused ? 1.045 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isFocused)
        #endif
    }
}

struct NoiseGlassGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @ViewBuilder var body: some View {
        if #available(iOS 26.0, tvOS 26.0, macOS 26.0, visionOS 26.0, *) {
            // Less than the eight-point picker gaps: adjacent levels remain
            // distinct instead of merging into a continuous glass capsule.
            GlassEffectContainer(spacing: 4) { content() }
        } else {
            content()
        }
    }
}
