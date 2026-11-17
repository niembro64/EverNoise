import XCTest
import PlaybackCore
@testable import JustBrownNoise

@MainActor
final class AudioPreferencesTests: XCTestCase {
    func testVolumeOffsetPersistsIndependentlyOfMixAndClampsOldValues() {
        let name = "EverNoise.offset-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let service = AudioService(defaults: defaults)
        XCTAssertEqual(service.volumeOffsetDB, 0)
        XCTAssertNil(defaults.object(forKey: VolumeOffset.preferenceKey))
        service.setVolumeOffsetDB(-7)
        service.selectMix(NoiseMix(highs: 4, mids: 1, lows: 0))
        XCTAssertEqual(AudioService(defaults: defaults).volumeOffsetDB, -7)
        service.setVolumeOffsetDB(100)
        XCTAssertEqual(AudioService(defaults: defaults).volumeOffsetDB, 3)
        defaults.set(-100, forKey: VolumeOffset.preferenceKey)
        XCTAssertEqual(AudioService(defaults: defaults).volumeOffsetDB, -18)
    }

    func testNewMixDefaultPreservesSavedAndLegacyBalances() {
        let name = "EverNoise.mix-preference-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(AudioService(defaults: defaults).selectedMix, NoiseMix(highs: 1, mids: 2, lows: 2))
        XCTAssertNil(defaults.object(forKey: "mixLows"), "Reading a fallback must not overwrite saved choices")
        defaults.set("brown", forKey: "selectedNoise")
        XCTAssertEqual(AudioService(defaults: defaults).selectedMix, .baseline)
        for mix in [NoiseMix(highs: 3, mids: 1, lows: 4), NoiseMix(highs: 0, mids: 0, lows: 0)] {
            mix.save(to: defaults)
            XCTAssertEqual(AudioService(defaults: defaults).selectedMix, mix)
        }
    }

    func testStereoDefaultsOnAndPreservesExplicitChoices() {
        let name = "EverNoise.stereo-preference-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertNil(defaults.object(forKey: "stereoEnabled"))
        let fresh = AudioService(defaults: defaults)
        XCTAssertTrue(fresh.stereoEnabled)
        XCTAssertNil(defaults.object(forKey: "stereoEnabled"), "A fallback must not replace a saved choice")
        fresh.setStereoEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: "stereoEnabled"))
        let returning = AudioService(defaults: defaults)
        XCTAssertFalse(returning.stereoEnabled, "An existing explicit Off must survive the new default")
        returning.setStereoEnabled(true)
        XCTAssertTrue(AudioService(defaults: defaults).stereoEnabled)
    }
}
