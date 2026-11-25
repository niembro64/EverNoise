import XCTest

final class TVPlaybackUITests: XCTestCase {
    @MainActor
    func testMaxSpectrogramAndOffKeepAudioIndependent() {
        let app = XCUIApplication()
        app.launchArguments = ["-animationLevel", "max", "-mixLevelsV2", "<dict><key>low</key><integer>2</integer><key>mid</key><integer>2</integer><key>high</key><integer>1</integer></dict>"]
        app.launch()
        XCTAssertTrue(app.buttons["playbackButton"].waitForExistence(timeout: 20))
        XCTAssertLessThan(app.buttons["band-high-1"].frame.midY, app.buttons["band-mid-2"].frame.midY)
        XCTAssertLessThan(app.buttons["band-mid-2"].frame.midY, app.buttons["band-low-2"].frame.midY)
        XCTAssertTrue(app.buttons["band-high-1"].isSelected)
        XCTAssertTrue(app.buttons["band-mid-2"].isSelected)
        XCTAssertTrue(app.buttons["band-low-2"].isSelected)
        XCTAssertTrue(app.otherElements["outputSpectrogram"].waitForExistence(timeout: 10))
        let plot = app.otherElements["outputSpectrogram"]
        func frameCount() -> UInt64 { UInt64((plot.value as? String ?? "").split(separator: "=").last ?? "") ?? 0 }
        expectation(for: NSPredicate { _, _ in frameCount() > 48000 }, evaluatedWith: app)
        waitForExpectations(timeout: 15)
        sleep(6)
        XCTAssertGreaterThan(frameCount(), 48000)
        let maxImage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        maxImage.name = "TV-Max-spectrogram"; maxImage.lifetime = .keepAlways; add(maxImage)
        XCUIRemote.shared.press(.playPause)
        XCTAssertTrue(waitForValue("Paused", on: app.buttons["playbackButton"]))
        sleep(1)
        let paused = frameCount()
        sleep(1)
        XCTAssertEqual(frameCount(), paused)
        app.terminate()
        app.launchArguments = ["-animationLevel", "off", "-mixLevelsV2", "<dict><key>low</key><integer>2</integer><key>mid</key><integer>2</integer><key>high</key><integer>1</integer></dict>"]
        app.launch()
        XCTAssertTrue(app.buttons["playbackButton"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.otherElements["outputSpectrogram"].exists)
        XCTAssertEqual(app.buttons["playbackButton"].value as? String, "Playing continuously")
        let offImage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        offImage.name = "TV-Off-artwork"; offImage.lifetime = .keepAlways; add(offImage)
    }

    @MainActor
    func testRemotePlayPauseAndBackgroundContinuity() {
        let app = XCUIApplication()
        app.launchArguments = ["-animationLevel", "low", "-mixLevelsV2", "<dict><key>low</key><integer>2</integer><key>mid</key><integer>2</integer><key>high</key><integer>1</integer></dict>"]
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
        app.launchArguments = ["-animationLevel", "low", "-mixLevelsV2", "<dict><key>low</key><integer>2</integer><key>mid</key><integer>2</integer><key>high</key><integer>1</integer></dict>"]
        app.launch()
        XCTAssertTrue(app.buttons["playbackButton"].waitForExistence(timeout: 20))
        let before = diagnostics(app)
        for band in ["low", "mid", "high"] {
            let selected = app.buttons["band-\(band)-5"]
            select(selected, in: app)
            XCTAssertTrue(selected.isSelected)
            for other in [0, 1, 2, 3, 4] { XCTAssertFalse(app.buttons["band-\(band)-\(other)"].isSelected) }
        }
        for band in ["low", "mid", "high"] {
            select(app.buttons["band-\(band)-1"], in: app)
            XCTAssertTrue(app.buttons["band-\(band)-1"].isSelected)
            XCTAssertTrue(app.buttons["band-\(band)-1"].label.contains("-30 decibels"))
        }
        let levels = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        levels.name = "TV-six-button-mix"; levels.lifetime = .keepAlways; add(levels)
        select(app.buttons["settingsButton"], in: app)
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["volumeOffsetPicker"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["App Loudness"].exists)
        XCUIRemote.shared.press(.select) // Native picker is the initially focused row.
        let choice = app.cells["-1 dB"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        for _ in 0..<24 {
            if choice.hasFocus { break }
            let focused = app.cells.allElementsBoundByIndex.first(where: { $0.hasFocus })
            let current = focused.flatMap { Int($0.label.split(separator: " ").first ?? "") }
            XCUIRemote.shared.press((current ?? -18) < -1 ? .down : .up)
        }
        XCTAssertTrue(choice.hasFocus)
        XCUIRemote.shared.press(.select)
        if !app.descendants(matching: .any)["volumeOffsetPicker"].firstMatch.waitForExistence(timeout: 2) {
            XCUIRemote.shared.press(.menu)
        }
        XCTAssertEqual(app.descendants(matching: .any)["volumeOffsetPicker"].firstMatch.value as? String, "-1 dB")
        XCUIRemote.shared.press(.down) // Show the saved label outside the native focus overlay.
        sleep(2) // Include the native sheet's separate window after focus settles.
        let settings = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        settings.name = "TV-app-loudness"; settings.lifetime = .keepAlways
        add(settings)
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
    func testEveryLowChoiceCanMoveDownToPlaybackControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-animationLevel", "low", "-mixLevelsV2",
            "<dict><key>low</key><integer>3</integer><key>mid</key><integer>3</integer><key>high</key><integer>2</integer></dict>"]
        app.launch()
        XCTAssertTrue(app.buttons["playbackButton"].waitForExistence(timeout: 20))
        for level in 0...5 {
            select(app.buttons["band-low-\(level)"], in: app)
            XCUIRemote.shared.press(.down)
            XCTAssertTrue(app.buttons["playbackButton"].hasFocus || app.buttons["settingsButton"].hasFocus,
                          "Down from Low \(level) must reach the bottom controls")
        }
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
