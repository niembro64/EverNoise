import XCTest
import UIKit
@testable import JustBrownNoise

final class BandNotchTests: XCTestCase {
    func testTouchPositionsResolveToTheOriginalFiveLevels() {
        for (position, expected): (Float, Int) in [(-1, 0), (0, 0), (0.12, 0), (0.13, 1),
                                                   (0.35, 1), (0.38, 2), (0.62, 2),
                                                   (0.65, 3), (0.87, 3), (0.88, 4), (2, 4)] {
            XCTAssertEqual(BandNotches.level(at: position), expected)
        }
        XCTAssertEqual(BandNotches.level(at: .nan), 0)
        for level in 0...4 {
            XCTAssertEqual(BandNotches.level(at: BandNotches.position(for: level)), level)
        }
    }

    @MainActor
    func testVoiceOverAdjustsOneStopAndNeverLeavesTheFiveChoices() throws {
        let slider = NotchedLevelSlider(frame: CGRect(x: 0, y: 0, width: 354, height: 56))
        slider.animatesChanges = false
        slider.setValue(0, animated: false)
        for expected in [1, 2, 3, 4, 4] {
            slider.accessibilityIncrement()
            XCTAssertEqual(slider.value, Float(expected) / 4)
            XCTAssertEqual(slider.accessibilityValue, "\(expected) of 4")
        }
        for expected in [3, 2, 1, 0, 0] {
            slider.accessibilityDecrement()
            XCTAssertEqual(slider.value, Float(expected) / 4)
            XCTAssertEqual(slider.accessibilityValue, expected == 0 ? "Off" : "\(expected) of 4")
        }
    }

    @MainActor
    func testReleasingBetweenStopsSettlesOnAnExactLevel() {
        let slider = NotchedLevelSlider(frame: CGRect(x: 0, y: 0, width: 354, height: 56))
        slider.animatesChanges = false
        for (position, expected): (Float, Float) in [(0.12, 0), (0.35, 0.25), (0.53, 0.5), (0.65, 0.75), (0.9, 1)] {
            slider.setValue(position, animated: false)
            slider.sendActions(for: .touchUpInside)
            XCTAssertEqual(slider.value, expected)
        }
    }
}
