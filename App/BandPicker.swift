import SwiftUI

/// Five direct choices, with a reflective glass rim for the selected tile.
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
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { value in
                    let selected = value == level
                    let tint = value == 0 ? Color(white: 0.065) :
                        (showsColor ? color(Double(value) / 4) : Color(white: 0.055 + Double(value) * 0.027))
                    Button { select(value) } label: {
                        IntensitySymbol(level: value)
                        .foregroundStyle(.white.opacity(0.92))
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
                    .accessibilityLabel(value == 0 ? "\(title), off" : "\(title), \(value) of 4")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title) frequency intensity")
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
                    .strokeBorder(lineWidth: 1.25)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .frame(width: CGFloat(2 + level * 4), height: CGFloat(2 + level * 4))
            }
        }
        .frame(width: 32, height: 28)
    }
}

