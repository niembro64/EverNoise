import Foundation

enum AnimationLevel: String, CaseIterable, Identifiable {
    case low
    case medium = "med"
    case high

    static let preferenceKey = "animationLevel"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .low: "Low"
        case .medium: "Med"
        case .high: "High"
        }
    }
    var animatesInfinity: Bool { self != .low }
    var showsRibbons: Bool { self == .high }

    /// Preserve an explicit old Off, while adopting Med for new installs and
    /// the old On setting. Once migrated, only the three-way choice is used.
    static func initialPreference(in defaults: UserDefaults = .standard) -> Self {
        if let stored = defaults.string(forKey: preferenceKey), let level = Self(rawValue: stored) {
            return level
        }
        let initial: Self = defaults.object(forKey: "animationsEnabled") as? Bool == false ? .low : .medium
        defaults.set(initial.rawValue, forKey: preferenceKey)
        return initial
    }
}
