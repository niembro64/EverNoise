import Foundation
import SpectrumAnalysis

/// Hue is a fixed reference to the production crossover curves. Only measured
/// output power changes brightness. All mixing happens in linear light.
struct SpectrogramPalette {
    static let floorDB: Float = -100
    static let referenceDB: Float = -35
    private let unitLuminanceColors: [SIMD3<Double>]

    init() {
        let bands = [NoisePalette.low, NoisePalette.mid, NoisePalette.high].map(LinearLight.decode)
        unitLuminanceColors = (0..<Int(BNSpectrumRows)).map { row in
            var weights = [Double](repeating: 0, count: 3)
            BNSpectrumReferenceWeights(BNSpectrumRowFrequency(UInt32(row)), &weights)
            let mixed = bands[0]*weights[0] + bands[1]*weights[1] + bands[2]*weights[2]
            return mixed / Self.luminance(mixed)
        }
    }

    static func luminance(_ rgb: SIMD3<Double>) -> Double {
        rgb.x*0.2126 + rgb.y*0.7152 + rgb.z*0.0722
    }

    static func lightness(decibels: Float) -> Double {
        guard decibels.isFinite else { return 0 }
        // A loudness-inspired contrast curve: +10 dB doubles the underlying
        // intensity proxy, then a soft shoulder keeps bright detail in gamut.
        // This is a fixed visual scale, not calibrated acoustic loudness/sones.
        // No adult hearing weighting or automatic exposure conceals a band.
        let aboveFloor = max(0, exp2(Double(decibels-referenceDB)/10)
                             - exp2(Double(floorDB-referenceDB)/10))
        return 70 * (1 - 1/(1+aboveFloor))
    }

    func linearColor(row: Int, decibels: Float) -> SIMD3<Double> {
        guard decibels.isFinite else { return .zero }
        // Equal octave energy receives equal CIELAB lightness across hues.
        // Green cannot appear louder just because its primary is brighter.
        let lightness = Self.lightness(decibels: decibels)
        let y = lightness <= 8 ? lightness/(24389.0/27) : pow((lightness+16)/116, 3)
        return unitLuminanceColors[row]*y
    }

    func linearColor16(row: Int, decibels: Float) -> SIMD3<UInt16> {
        let linear = linearColor(row: row, decibels: decibels)
        func component(_ channel: Double) -> UInt16 {
            UInt16((min(1, max(0, channel))*65535).rounded())
        }
        return SIMD3(component(linear.x), component(linear.y), component(linear.z))
    }

    func encodedColor(row: Int, decibels: Float) -> SIMD3<UInt8> {
        let linear = linearColor(row: row, decibels: decibels)
        func byte(_ channel: Double) -> UInt8 {
            UInt8((min(1, max(0, LinearLight.encode(channel)))*255).rounded())
        }
        return SIMD3(byte(linear.x), byte(linear.y), byte(linear.z))
    }
}
