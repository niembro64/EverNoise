import SwiftUI
import PlaybackCore

/// Compress the power range for legibility: literal power-proportional area
/// would make the quietest dot smaller than a pixel. Area grows with sqrt(power)
/// and tint light energy with cbrt(power); both encode strength, not button index.
enum BandLevelAppearance {
    static func dotDiameter(at level: Int) -> Double {
        22 * pow(NoiseMix.relativePower(at: level), 0.25)
    }
    static func tintIntensity(at level: Int) -> Double {
        pow(NoiseMix.relativePower(at: level), 1.0 / 3)
    }
}

/// Six direct choices, with a reflective glass rim for the selected tile.
struct BandPicker: View {
    let title: String
    let id: String
    let level: Int
    let showsColor: Bool
    let animate: Bool
    let color: (Double) -> Color
    let select: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.band)
                .foregroundStyle(Color(white: 0.75))
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: buttonSpacing) {
                ForEach(NoiseMix.levels, id: \.self) { value in
                    let selected = value == level
                    let strength = BandLevelAppearance.tintIntensity(at: value)
                    let tint = value == 0 ? Color(white: 0.065) :
                        (showsColor ? color(strength) : Color(white: 0.055 + strength * 0.108))
                    Button { select(value) } label: {
                        IntensitySymbol(level: value)
                        .foregroundStyle(.white.opacity(value == 0 ? 0.55 : 0.55 + 0.37 * strength))
                        .frame(minWidth: 44, maxWidth: .infinity, minHeight: 56)
                        .overlay {
                            GlassSelectionRim()
                                .opacity(selected ? 1 : 0)
                                .allowsHitTesting(false)
                        }
                        .contentShape(Rectangle())
                        .animation(animate ? .easeInOut(duration: 1.4) : nil, value: showsColor)
                        .animation(animate ? .easeInOut(duration: 0.5) : nil, value: selected)
                    }
                    .buttonStyle(NoiseGlassButtonStyle(tint: tint, shape: RoundedRectangle(cornerRadius: 12), interactive: animate, colorful: showsColor, usesClearGlass: true))
                    .animation(animate ? .easeInOut(duration: 1.4) : nil, value: showsColor)
                    .accessibilityIdentifier("band-\(id)-\(value)")
                    .accessibilityLabel("\(title), \(NoiseMix.levelDescription(value))")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title) frequency mix")
    }

    private var buttonSpacing: CGFloat {
        #if os(tvOS)
        8 // Leave room for the native focus enlargement on the remote UI.
        #else
        4 // Six 44-point targets still fit a narrow phone or iPad window.
        #endif
    }
}

/// A bright outer reflection and fine inner edge read as glass thickness.
/// Its only motion is a gentle selection fade; it never bounces or shimmers.
private struct GlassSelectionRim: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        shape.fill(LinearGradient(colors: [.white.opacity(0.10), .clear, .white.opacity(0.025)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.94), .white.opacity(0.24), .white.opacity(0.70)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5)
            }
            .overlay {
                shape.inset(by: 3.5).strokeBorder(.white.opacity(0.18), lineWidth: 0.75)
            }
    }
}

private struct IntensitySymbol: View {
    let level: Int

    var body: some View {
        Group {
            if level == 0 {
                Circle()
                    .strokeBorder(lineWidth: 1)
                    .frame(width: 6, height: 6)
            } else {
                Circle()
                    .frame(width: BandLevelAppearance.dotDiameter(at: level), height: BandLevelAppearance.dotDiameter(at: level))
            }
        }
        .frame(width: 32, height: 28)
    }
}

