import Foundation

enum AnimationLevel: String, CaseIterable, Identifiable {
    case off
    case low
    case medium = "med"
    case high
    case maximum = "max"

    static let preferenceKey = "animationLevel"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: "Off"
        case .low: "Low"
        case .medium: "Med"
        case .high: "High"
        case .maximum: "Max"
        }
    }
    var animatesArtwork: Bool { self == .medium || self == .high || self == .maximum }
    var showsRibbons: Bool { self == .high || self == .maximum }
    var showsInfinity: Bool { self == .low || self == .medium || self == .high }

    /// Preserve an explicit old Off, while adopting Med for new installs and
    /// the old On setting. Saved Low/Med/High retain their existing meaning.
    static func initialPreference(in defaults: UserDefaults = .standard) -> Self {
        if let stored = defaults.string(forKey: preferenceKey), let level = Self(rawValue: stored) {
            return level
        }
        let initial: Self = defaults.object(forKey: "animationsEnabled") as? Bool == false ? .low : .medium
        defaults.set(initial.rawValue, forKey: preferenceKey)
        return initial
    }
}
