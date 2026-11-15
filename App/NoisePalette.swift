import SwiftUI

/// A restrained six-hue family, all authored at OKLCH L=0.60, C=0.085.
/// Authoring values are sRGB. Decode once before lighting, tint intensity,
/// palette interpolation, or transparency compositing.
enum NoisePalette {
    static let hues: [SIMD3<Double>] = [
        SIMD3(0.679977, 0.422528, 0.401320), // muted rose
        SIMD3(0.580084, 0.493912, 0.253602), // antique gold
        SIMD3(0.373181, 0.556164, 0.377719), // sage
        SIMD3(0.202675, 0.562493, 0.581097), // sea glass
        SIMD3(0.404896, 0.499108, 0.704015), // periwinkle
        SIMD3(0.604564, 0.432928, 0.613018)  // mauve
    ]
    static let low = hues[0], mid = hues[2], high = hues[4]
    static let linearHues = hues.map { LinearLight.decode($0) }
    static let accent = Color(.sRGB, red: 0.38, green: 0.66, blue: 0.52)

    static func color(_ components: SIMD3<Double>, intensity: Double = 1) -> Color {
        let rgb = LinearLight.decode(components) * intensity
        return Color(.sRGBLinear, red: rgb.x, green: rgb.y, blue: rgb.z)
    }
}
