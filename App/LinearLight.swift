import Foundation

/// Exact extended sRGB transfer function. RGB arithmetic happens in linear
/// light; alpha is coverage/transmittance and is never gamma corrected.
/// https://www.w3.org/TR/css-color-4/#color-conversion-code
enum LinearLight {
    static func decode(_ encoded: Double) -> Double {
        let magnitude = abs(encoded)
        return magnitude <= 0.04045 ? encoded / 12.92
            : (encoded < 0 ? -1 : 1) * pow((magnitude + 0.055) / 1.055, 2.4)
    }

    static func encode(_ linear: Double) -> Double {
        let magnitude = abs(linear)
        return magnitude <= 0.0031308 ? 12.92 * linear
            : (linear < 0 ? -1 : 1) * (1.055 * pow(magnitude, 1 / 2.4) - 0.055)
    }

    static func decode(_ encoded: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(decode(encoded.x), decode(encoded.y), decode(encoded.z))
    }
}
