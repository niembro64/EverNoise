import Foundation
import SpectrumAnalysis

/// Hue is a fixed reference to the production crossover curves. Only measured
/// output power changes brightness. All mixing happens in linear light.
struct SpectrogramPalette {
    static let floorDB: Float = -120
    static let ceilingDB: Float = -30
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

    func linearColor(row: Int, decibels: Float) -> SIMD3<Double> {
        guard decibels.isFinite else { return .zero }
        let level = Double(min(1, max(0, (decibels-Self.floorDB)/(Self.ceilingDB-Self.floorDB))))
        // Equal decibel increments receive equal CIELAB L* increments. The
        // restrained 0...70 lightness range keeps every hue inside sRGB gamut.
        // Green cannot appear louder just because its primary is brighter.
        let lightness = level*70
        let y = lightness <= 8 ? lightness/(24389.0/27) : pow((lightness+16)/116, 3)
        return unitLuminanceColors[row]*y
    }

    func encodedColor(row: Int, decibels: Float) -> SIMD3<UInt8> {
        let linear = linearColor(row: row, decibels: decibels)
        func byte(_ channel: Double) -> UInt8 {
            UInt8((min(1, max(0, LinearLight.encode(channel)))*255).rounded())
        }
        return SIMD3(byte(linear.x), byte(linear.y), byte(linear.z))
    }
}
