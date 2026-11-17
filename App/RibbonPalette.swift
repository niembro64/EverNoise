import Foundation
import PlaybackCore

/// Shared inputs for every ribbon. The body combines the shared muted palette;
/// spectral accents use power, not the linear picker index or sample amplitude.
struct RibbonPalette: Equatable {
    let mixedColor: SIMD3<Double>
    let bandPower: SIMD3<Double>

    init(mix: NoiseMix) {
        bandPower = SIMD3(Self.power(at: mix.lows), Self.power(at: mix.mids), Self.power(at: mix.highs))
        // Add light energy using the same logarithmic powers as the spectral
        // distribution. Display mapping happens once, after all compositing.
        mixedColor = NoisePalette.linearHues[0] * bandPower.x
            + NoisePalette.linearHues[2] * bandPower.y
            + NoisePalette.linearHues[4] * bandPower.z
    }

    static func power(at level: Int) -> Double {
        NoiseMix.relativePower(at: level)
    }
}
