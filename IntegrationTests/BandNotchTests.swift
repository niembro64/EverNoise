import XCTest
import UIKit
import PlaybackCore
@testable import JustBrownNoise

final class BandNotchTests: XCTestCase {
    func testTouchPositionsResolveToTheSixLevels() {
        for (position, expected): (Float, Int) in [(-1, 0), (0, 0), (0.09, 0), (0.11, 1),
                                                   (0.29, 1), (0.31, 2), (0.49, 2),
                                                   (0.51, 3), (0.69, 3), (0.71, 4),
                                                   (0.89, 4), (0.91, 5), (2, 5)] {
            XCTAssertEqual(BandNotches.level(at: position), expected)
        }
        XCTAssertEqual(BandNotches.level(at: .nan), 0)
        for level in NoiseMix.levels {
            XCTAssertEqual(BandNotches.level(at: BandNotches.position(for: level)), level)
        }
    }

    @MainActor
    func testVoiceOverAdjustsOneStopAndNeverLeavesTheSixChoices() throws {
        let slider = NotchedLevelSlider(frame: CGRect(x: 0, y: 0, width: 354, height: 56))
        slider.animatesChanges = false
        slider.setValue(0, animated: false)
        for expected in [1, 2, 3, 4, 5, 5] {
            slider.accessibilityIncrement()
            XCTAssertEqual(slider.value, Float(expected) / 5)
            XCTAssertEqual(slider.accessibilityValue, NoiseMix.levelDescription(expected))
        }
        for expected in [4, 3, 2, 1, 0, 0] {
            slider.accessibilityDecrement()
            XCTAssertEqual(slider.value, Float(expected) / 5)
            XCTAssertEqual(slider.accessibilityValue, expected == 0 ? "Off" : NoiseMix.levelDescription(expected))
        }
    }

    @MainActor
    func testReleasingBetweenStopsSettlesOnAnExactLevel() {
        let slider = NotchedLevelSlider(frame: CGRect(x: 0, y: 0, width: 354, height: 56))
        slider.animatesChanges = false
        for (position, expected): (Float, Float) in [(0.09, 0), (0.25, 0.2), (0.43, 0.4), (0.65, 0.6), (0.81, 0.8), (0.93, 1)] {
            slider.setValue(position, animated: false)
            slider.sendActions(for: .touchUpInside)
            XCTAssertEqual(slider.value, expected)
        }
    }

    func testPowerIndicatorsAreMonotonicAndTheTraceRemainsLegible() {
        XCTAssertEqual(BandLevelAppearance.dotDiameter(at: 0), 0)
        XCTAssertGreaterThanOrEqual(BandLevelAppearance.dotDiameter(at: 1), 3.5)
        XCTAssertEqual(BandLevelAppearance.dotDiameter(at: 5), 22)
        XCTAssertEqual(BandLevelAppearance.tintIntensity(at: 1), 0.1, accuracy: 1e-12)
        for level in 1...5 {
            XCTAssertGreaterThan(BandLevelAppearance.dotDiameter(at: level), BandLevelAppearance.dotDiameter(at: level-1))
            XCTAssertGreaterThan(BandLevelAppearance.tintIntensity(at: level), BandLevelAppearance.tintIntensity(at: level-1))
        }
        let diameterRatio = BandLevelAppearance.dotDiameter(at: 1) / BandLevelAppearance.dotDiameter(at: 2)
        XCTAssertEqual(pow(diameterRatio, 4), NoiseMix.relativePower(at: 1) / NoiseMix.relativePower(at: 2), accuracy: 1e-12)
    }
}
