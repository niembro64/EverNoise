import Foundation

/// Relative band weights: off, then -30, -18, -12, -6, and 0 dB before shared
/// loudness normalization. A proportional change preserves tone and loudness.
public struct NoiseMix: Equatable, Hashable, Sendable {
    public let lows: Int
    public let highs: Int
    public let mids: Int
    public static let maximumLevel = 5
    public static let levels = 0...maximumLevel
    /// One property-list value commits all three coordinates together. The old
    /// keys remain untouched, so neither a second load nor a rollback shifts them.
    public static let preferenceKey = "mixLevelsV2"
    public static let baseline = NoiseMix(highs: 0, mids: 0)
    /// Same -12/-12/-18 dB balance, now fourth Low/Mid and third High.
    /// The original Brown baseline remains available and is never redefined.
    public static let defaultMix = NoiseMix(highs: 2, mids: 3, lows: 3)

    public init(highs: Int, mids: Int, lows: Int = maximumLevel) {
        self.lows = Self.clamp(lows)
        self.highs = Self.clamp(highs)
        self.mids = Self.clamp(mids)
    }

    public static func clamp(_ level: Int) -> Int { min(maximumLevel, max(0, level)) }
    public static func relativeDecibels(at level: Int) -> Double? {
        [nil, -30, -18, -12, -6, 0][clamp(level)]
    }
    /// Power relative to a full-strength band, before shared normalization.
    public static func relativePower(at level: Int) -> Double {
        relativeDecibels(at: level).map { pow(10, $0 / 10) } ?? 0
    }
    public static func levelDescription(_ level: Int) -> String {
        guard let dB = relativeDecibels(at: level) else { return "Off" }
        return "\(clamp(level)) of \(maximumLevel), \(Int(dB)) decibels relative"
    }

    public var summary: String { "Low \(lows) · Mid \(mids) · High \(highs)" }
    public var isSilent: Bool { lows == 0 && mids == 0 && highs == 0 }

    public static func load(from defaults: UserDefaults) -> NoiseMix {
        if let saved = defaults.dictionary(forKey: preferenceKey),
           let low = saved["low"] as? Int, let mid = saved["mid"] as? Int,
           let high = saved["high"] as? Int {
            return NoiseMix(highs: high, mids: mid, lows: low)
        }
        if defaults.object(forKey: "mixHighs") != nil,
           defaults.object(forKey: "mixMids") != nil {
            // Inserting a quiet choice must not make an existing mix quieter.
            // Read the old coordinate system without ever writing back into it.
            func migrate(_ old: Int) -> Int {
                let clamped = min(4, max(0, old))
                return clamped == 0 ? 0 : clamped + 1
            }
            return NoiseMix(highs: migrate(defaults.integer(forKey: "mixHighs")),
                            mids: migrate(defaults.integer(forKey: "mixMids")),
                            lows: defaults.object(forKey: "mixLows") == nil ? maximumLevel : migrate(defaults.integer(forKey: "mixLows")))
        }
        // Preserve the former Brown/Gray balances on upgrade. White becomes
        // the brightest mix. An older install has no bass control, so its low
        // layer stays at the original full level until explicitly changed.
        switch defaults.string(forKey: "selectedNoise") {
        case "brown": return .baseline
        case "gray": return NoiseMix(highs: maximumLevel, mids: 0)
        case "white": return NoiseMix(highs: maximumLevel, mids: maximumLevel)
        default: return .defaultMix
        }
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(["low": lows, "mid": mids, "high": highs], forKey: Self.preferenceKey)
    }
}
