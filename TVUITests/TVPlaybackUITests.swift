import XCTest

final class TVPlaybackUITests: XCTestCase {
    @MainActor
    func testRemotePlayPauseAndBackgroundContinuity() {
        let app = XCUIApplication()
        app.launchArguments = ["-animationLevel", "low", "-mixLows", "2", "-mixMids", "2", "-mixHighs", "1"]
        app.launch()
        let playback = app.buttons["playbackButton"]
        XCTAssertTrue(playback.waitForExistence(timeout: 20))
        XCTAssertEqual(playback.value as? String, "Playing continuously")
        let before = diagnostics(app)
        XCUIRemote.shared.press(.home)
        sleep(3)
        app.activate()
        XCTAssertTrue(playback.waitForExistence(timeout: 15))
        XCTAssertEqual(playback.value as? String, "Playing continuously")
        let after = diagnostics(app)
        XCTAssertEqual(before.count, 2)
        XCTAssertEqual(after.count, 2)
        if before.count == 2 && after.count == 2 {
            XCTAssertEqual(before[0], after[0], "Returning from Home must not restart the engine")
            XCTAssertGreaterThan(after[1], before[1] + 48_000, "The audio clock must advance in the background")
        }
        XCUIRemote.shared.press(.playPause)
        XCTAssertTrue(waitForValue("Paused", on: playback), "One remote press must pause exactly once")
        XCUIRemote.shared.press(.playPause)
        XCTAssertTrue(waitForValue("Playing continuously", on: playback))
        select(playback, in: app)
        XCTAssertTrue(waitForValue("Paused", on: playback))
    }

    @MainActor
    func testRemoteCanSelectBandsAndOpenSettingsWithoutRestartingAudio() {
        let app = XCUIApplication()
        app.launchArguments = ["-animationLevel", "low", "-mixLows", "2", "-mixMids", "2", "-mixHighs", "1"]
        app.launch()
        XCTAssertTrue(app.buttons["playbackButton"].waitForExistence(timeout: 20))
        let before = diagnostics(app)
        for band in ["low", "mid", "high"] {
            let selected = app.buttons["band-\(band)-3"]
            select(selected, in: app)
            XCTAssertTrue(selected.isSelected)
            for other in [0, 1, 2, 4] { XCTAssertFalse(app.buttons["band-\(band)-\(other)"].isSelected) }
        }
        select(app.buttons["settingsButton"], in: app)
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["playbackButton"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["playbackButton"].value as? String, "Playing continuously")
        let after = diagnostics(app)
        if before.count == 2 && after.count == 2 {
            XCTAssertEqual(before[0], after[0])
            XCTAssertGreaterThan(after[1], before[1])
        } else { XCTFail("Missing audio diagnostics") }
    }

    @MainActor
    private func select(_ target: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if target.hasFocus {
                XCUIRemote.shared.press(.select)
                return
            }
            guard let focused = app.buttons.allElementsBoundByIndex.first(where: { $0.hasFocus }) else {
                XCTFail("No focused button")
                return
            }
            let dx = target.frame.midX - focused.frame.midX
            let dy = target.frame.midY - focused.frame.midY
            let direction: XCUIRemote.Button = abs(dy) > target.frame.height / 2
                ? (dy < 0 ? .up : .down) : (dx < 0 ? .left : .right)
            XCUIRemote.shared.press(direction)
        }
        XCTFail("Remote could not reach \(target.identifier)")
    }

    @MainActor
    private func waitForValue(_ value: String, on element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }

    @MainActor
    private func diagnostics(_ app: XCUIApplication) -> [UInt64] {
        app.staticTexts["audioDiagnostics"].label.split(separator: ":").compactMap { UInt64($0) }
    }
}
