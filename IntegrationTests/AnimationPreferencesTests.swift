import XCTest
@testable import JustBrownNoise

final class AnimationPreferencesTests: XCTestCase {
    func testOffAndMaxHaveDistinctRenderingPolicies() {
        XCTAssertFalse(AnimationLevel.off.animatesArtwork)
        XCTAssertFalse(AnimationLevel.off.showsInfinity)
        XCTAssertFalse(AnimationLevel.off.showsRibbons)
        XCTAssertTrue(AnimationLevel.maximum.animatesArtwork)
        XCTAssertFalse(AnimationLevel.maximum.showsInfinity)
        XCTAssertTrue(AnimationLevel.maximum.showsRibbons)
        XCTAssertEqual(AnimationLevel.allCases.map(\.title), ["Off", "Low", "Med", "High", "Max"])
    }
    func testDefaultMigrationAndAllSavedLevels() {
        let name = "EverNoise.animation-preference-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(AnimationLevel.initialPreference(in: defaults), .medium)
        XCTAssertEqual(defaults.string(forKey: AnimationLevel.preferenceKey), "med")

        for legacy in [true, false] {
            defaults.removePersistentDomain(forName: name)
            defaults.set(legacy, forKey: "animationsEnabled")
            XCTAssertEqual(AnimationLevel.initialPreference(in: defaults), legacy ? .medium : .low)
        }
        for level in AnimationLevel.allCases {
            defaults.set(level.rawValue, forKey: AnimationLevel.preferenceKey)
            XCTAssertEqual(AnimationLevel.initialPreference(in: defaults), level,
                           "A saved level must win over the obsolete boolean")
        }
        defaults.removePersistentDomain(forName: name)
        defaults.set("invalid", forKey: AnimationLevel.preferenceKey)
        XCTAssertEqual(AnimationLevel.initialPreference(in: defaults), .medium)
    }
}
