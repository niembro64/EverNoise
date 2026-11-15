import Foundation

/// Independent band levels: off, then -18, -12, -6, and 0 dB.
public struct NoiseMix: Equatable, Hashable, Sendable {
    public let lows: Int
    public let highs: Int
    public let mids: Int
    public static let baseline = NoiseMix(highs: 0, mids: 0)
    /// Third Low, third Mid, second High button, counting Off as first.
    /// The original Brown baseline remains available and is never redefined.
    public static let defaultMix = NoiseMix(highs: 1, mids: 2, lows: 2)

    public init(highs: Int, mids: Int, lows: Int = 4) {
        self.lows = min(4, max(0, lows))
        self.highs = min(4, max(0, highs))
        self.mids = min(4, max(0, mids))
    }

    public var summary: String { "Low \(lows) · Mid \(mids) · High \(highs)" }
    public var isSilent: Bool { lows == 0 && mids == 0 && highs == 0 }

    public static func load(from defaults: UserDefaults) -> NoiseMix {
        if defaults.object(forKey: "mixHighs") != nil,
           defaults.object(forKey: "mixMids") != nil {
            return NoiseMix(highs: defaults.integer(forKey: "mixHighs"),
                            mids: defaults.integer(forKey: "mixMids"),
                            lows: defaults.object(forKey: "mixLows") == nil ? 4 : defaults.integer(forKey: "mixLows"))
        }
        // Preserve the former Brown/Gray balances on upgrade. White becomes
        // the brightest mix. An older install has no bass control, so its low
        // layer stays at the original full level until explicitly changed.
        switch defaults.string(forKey: "selectedNoise") {
        case "brown": return .baseline
        case "gray": return NoiseMix(highs: 4, mids: 0)
        case "white": return NoiseMix(highs: 4, mids: 4)
        default: return .defaultMix
        }
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(lows, forKey: "mixLows")
        defaults.set(highs, forKey: "mixHighs")
        defaults.set(mids, forKey: "mixMids")
    }
}
