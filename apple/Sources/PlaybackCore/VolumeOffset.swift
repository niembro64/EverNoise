import Foundation

/// App-relative loudness preference; never writes the device's system volume.
public enum VolumeOffset {
    public static let preferenceKey = "volumeOffsetDB"
    public static let range = -18...3
    public static func clamp(_ value: Int) -> Int { min(range.upperBound, max(range.lowerBound, value)) }
    public static func load(from defaults: UserDefaults) -> Int {
        clamp(defaults.integer(forKey: preferenceKey))
    }
    public static func label(_ value: Int) -> String {
        let value = clamp(value)
        return value > 0 ? "+\(value) dB" : "\(value) dB"
    }
}
