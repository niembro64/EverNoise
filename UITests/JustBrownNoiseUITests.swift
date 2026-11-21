import XCTest
import UIKit

final class JustBrownNoiseUITests: XCTestCase {
    @MainActor
    func testSystemControlsGuidePreservesPlayback() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-animationLevel", "low"]
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        let before = app.staticTexts["audioDiagnostics"].label.split(separator: ":").first
        app.buttons["settingsButton"].tap()
        let guide = app.buttons["systemControlsGuide"]
        for _ in 0..<4 {
            if guide.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(guide.isHittable)
        guide.tap()
        XCTAssertTrue(app.navigationBars["Widgets & shortcuts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Touch and hold your Home Screen")).firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Widgets-and-shortcuts-guide"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.navigationBars.buttons["Settings"].tap()
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["playbackButton"].value as? String, "Playing continuously")
        XCTAssertEqual(app.staticTexts["audioDiagnostics"].label.split(separator: ":").first, before)
    }

    @MainActor
    func testOffAndMaxSpectrogramPreserveContinuousAudio() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-volumeOffsetDB", "0", "-mixLevelsV2", "<dict><key>low</key><integer>2</integer><key>mid</key><integer>2</integer><key>high</key><integer>1</integer></dict>"]
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        XCTAssertLessThan(app.buttons["band-high-1"].frame.midY, app.buttons["band-mid-2"].frame.midY)
        XCTAssertLessThan(app.buttons["band-mid-2"].frame.midY, app.buttons["band-low-2"].frame.midY)
        XCTAssertTrue(app.buttons["band-high-1"].isSelected)
        XCTAssertTrue(app.buttons["band-mid-2"].isSelected)
        XCTAssertTrue(app.buttons["band-low-2"].isSelected)
        let before = app.staticTexts["audioDiagnostics"].label.split(separator: ":").compactMap { UInt64($0) }
        func chooseVisual(_ title: String) {
            app.buttons["settingsButton"].tap()
            let picker = app.segmentedControls["animationLevelPicker"]
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            picker.buttons[title].tap()
            XCTAssertTrue(picker.buttons[title].isSelected)
            _ = capture(app, named: "Visual-settings-\(title)")
            app.buttons["Done"].tap()
        }
        chooseVisual("Off")
        sleep(1)
        let off = capture(app, named: "Off-no-artwork")
        let mark = app.otherElements["noiseColor"]
        XCTAssertEqual(pixels(off, in: mark.frame).coloredCount, 0)
        XCTAssertFalse(app.otherElements["outputSpectrogram"].exists)
        sleep(1)
        let still = capture(app, named: "Off-no-display-motion")
        XCTAssertEqual(differences(pixels(off, in: mark.frame), pixels(still, in: mark.frame), minimumChange: 0), 0)
        chooseVisual("Max")
        XCTAssertTrue(app.otherElements["outputSpectrogram"].waitForExistence(timeout: 5))
        let plot = app.otherElements["outputSpectrogram"]
        XCTAssertTrue((plot.value as? String ?? "").contains("2 hertz to 24 kilohertz"))
        XCTAssertTrue((plot.value as? String ?? "").contains("48 kilohertz"))
        func frameCount() -> UInt64 { UInt64((plot.value as? String ?? "").split(separator: "=").last ?? "") ?? 0 }
        let running = NSPredicate { _, _ in frameCount() > 48000 }
        expectation(for: running, evaluatedWith: app)
        waitForExpectations(timeout: 12)
        sleep(24) // Fill the entire history before inspecting frequency detail.
        let maximum = capture(app, named: "Max-output-spectrogram")
        XCTAssertGreaterThan(pixels(maximum, in: mark.frame).coloredCount, 1000)
        let first = frameCount()
        sleep(1)
        XCTAssertGreaterThan(frameCount(), first)
        app.buttons["playbackButton"].tap()
        sleep(4) // Allow the existing gradual ribbon color transition to settle.
        let pausedFrame = frameCount()
        let paused = capture(app, named: "Max-paused-spectrogram")
        // The rendered color conversion can differ by 1–2 least-significant
        // byte values; coloredCount excludes that imperceptible rounding.
        XCTAssertEqual(pixels(paused, in: plot.frame).coloredCount, 0)
        sleep(1)
        XCTAssertEqual(frameCount(), pausedFrame, "Paused analysis must stop")
        app.buttons["playbackButton"].tap()
        chooseVisual("Off")
        choose(3, band: "mid", in: app)
        let after = app.staticTexts["audioDiagnostics"].label.split(separator: ":").compactMap { UInt64($0) }
        XCTAssertEqual(before.count, 2); XCTAssertEqual(after.count, 2)
        if before.count == 2 && after.count == 2 {
            XCTAssertEqual(after[0], before[0]+1, "Only the explicit pause/resume may restart audio")
            XCTAssertGreaterThan(after[1], before[1])
        }
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.segmentedControls["animationLevelPicker"].buttons["Off"].isSelected)
        app.segmentedControls["animationLevelPicker"].buttons["Max"].tap()
        let guidance = app.staticTexts["familyHearingGuidance"]
        for _ in 0..<6 {
            if guidance.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(guidance.isHittable)
        XCTAssertTrue(guidance.label.contains("may hear high frequencies"))
        _ = capture(app, named: "Family-hearing-guidance")
        let listening = app.staticTexts["familyListeningGuidance"]
        for _ in 0..<4 {
            if listening.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(listening.isHittable)
        _ = capture(app, named: "Family-listening-guidance")
        app.buttons["Done"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.otherElements["outputSpectrogram"].waitForExistence(timeout: 15))
    }

    @MainActor
    func testSavedVolumeOffsetKeepsPlaybackRunning() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-volumeOffsetDB", "0", "-animationLevel", "low", "-mixLevelsV2", "<dict><key>low</key><integer>2</integer><key>mid</key><integer>2</integer><key>high</key><integer>1</integer></dict>"]
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        let before = app.staticTexts["audioDiagnostics"].label.split(separator: ":").compactMap { UInt64($0) }
        app.buttons["settingsButton"].tap()
        let slider = app.sliders["volumeOffsetSlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["App Loudness"].exists)
        XCTAssertEqual(slider.label, "App Loudness")
        XCTAssertEqual(app.staticTexts["volumeOffsetValue"].label, "0 dB")
        slider.adjust(toNormalizedSliderPosition: 0.285714)
        let saved = app.staticTexts["volumeOffsetValue"].label
        XCTAssertNotEqual(saved, "0 dB")
        XCTAssertTrue(saved.hasPrefix("-"))
        _ = capture(app, named: "Settings-app-loudness")
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["playbackButton"].value as? String, "Playing continuously")
        let after = app.staticTexts["audioDiagnostics"].label.split(separator: ":").compactMap { UInt64($0) }
        XCTAssertEqual(before.count, 2); XCTAssertEqual(after.count, 2)
        if before.count == 2 && after.count == 2 {
            XCTAssertEqual(before[0], after[0]); XCTAssertGreaterThan(after[1], before[1])
        }
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["volumeOffsetValue"].label, saved)
        app.buttons["Done"].tap()
        app.buttons["playbackButton"].tap()
        app.buttons["settingsButton"].tap()
        slider.adjust(toNormalizedSliderPosition: 0.571429)
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["playbackButton"].value as? String, "Paused")
    }

    @MainActor
    func testStereoPreferencePersistsWithoutRestartingPlayback() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-stereoEnabled", "NO", "-mixLevelsV2", "<dict><key>low</key><integer>4</integer><key>mid</key><integer>2</integer><key>high</key><integer>3</integer></dict>"]
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        let before = app.staticTexts["audioDiagnostics"].label.split(separator: ":").compactMap { UInt64($0) }
        let settings = app.buttons["settingsButton"]
        XCTAssertGreaterThanOrEqual(settings.frame.width, 80)
        XCTAssertGreaterThanOrEqual(settings.frame.height, 80)
        // Hit well outside the visible 22-point gear, inside its larger target.
        settings.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.85)).tap()
        let picker = app.segmentedControls["audioModePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.buttons["Mono"].isSelected)
        _ = capture(app, named: "Settings-audio-mono")
        picker.buttons["Stereo"].tap()
        XCTAssertTrue(picker.buttons["Stereo"].isSelected)
        _ = capture(app, named: "Settings-audio-stereo")
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["playbackButton"].value as? String, "Playing continuously")
        let after = app.staticTexts["audioDiagnostics"].label.split(separator: ":").compactMap { UInt64($0) }
        XCTAssertEqual(before.count, 2); XCTAssertEqual(after.count, 2)
        if before.count == 2 && after.count == 2 {
            XCTAssertEqual(before[0], after[0], "Stereo must not restart audio")
            XCTAssertGreaterThan(after[1], before[1])
        }
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.buttons["Stereo"].isSelected, "Stereo preference must survive reopening")
        app.buttons["Done"].tap()
        app.buttons["playbackButton"].tap()
        app.buttons["settingsButton"].tap()
        picker.buttons["Mono"].tap()
        XCTAssertTrue(picker.buttons["Mono"].isSelected)
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["playbackButton"].value as? String, "Paused", "Changing stereo must preserve pause")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(picker.buttons["Mono"].isSelected, "Choosing Mono must also persist")
        app.buttons["Done"].tap()
    }

    @MainActor
    func testPlaybackVisuals() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-animationLevel", "high", "-mixLevelsV2", "<dict><key>low</key><integer>4</integer><key>mid</key><integer>2</integer><key>high</key><integer>3</integer></dict>"]
        app.launch()
        let button = app.buttons["playbackButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        let mark = app.otherElements["noiseColor"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(mark.frame.width, app.frame.width * 0.8)
        XCTAssertGreaterThan(mark.frame.height, app.frame.height * 0.2)
        XCTAssertTrue(button.isHittable, "Enlarging the infinity must keep playback within reach")
        XCTAssertEqual(button.value as? String, "Playing continuously")
        sleep(4) // Let the deliberately gradual launch transition settle.
        let playing = capture(app, named: "Playing-color")
        sleep(1)
        let flowing = capture(app, named: "Playing-flow")
        let content = app.frame.insetBy(dx: 24, dy: 90)
        XCTAssertGreaterThan(pixels(playing, in: content).coloredCount, 1_000)
        for (hue, count) in pixels(playing, in: mark.frame).hueCounts.enumerated() {
            XCTAssertGreaterThan(count, 3, "Every color-wheel hue should remain visible in the fine strands (hue \(hue))")
        }
        XCTAssertGreaterThan(differences(pixels(playing, in: mark.frame), pixels(flowing, in: mark.frame)), 1_000,
                             "The infinity ribbon should move during playback")
        // The lower outer gutter contains no controls or foreground infinity.
        let background = CGRect(x: app.frame.minX + 2, y: app.frame.height * 0.52,
                                width: 18, height: app.frame.height * 0.38)
        XCTAssertGreaterThan(pixels(playing, in: background).coloredCount, 100, "Faint background ribbons should be visible")
        XCTAssertGreaterThan(differences(pixels(playing, in: background), pixels(flowing, in: background), minimumChange: 0), 100,
                             "Background ribbons should move in the lower screen, too")

        button.tap()
        XCTAssertEqual(button.value as? String, "Paused")
        sleep(4) // Flow decelerates and color drains before the display goes idle.
        let paused = capture(app, named: "Paused-grayscale")
        sleep(1)
        let still = capture(app, named: "Paused-still")
        assertGrayscale(pixels(paused, in: content))
        XCTAssertEqual(pixels(paused, in: mark.frame).coloredCount, 0, "Paused artwork must be exactly grayscale")
        XCTAssertEqual(differences(pixels(paused, in: mark.frame), pixels(still, in: mark.frame), minimumChange: 0), 0,
                       "The paused infinity ribbon should be still")

        for band in ["low", "mid", "high"] { choose(0, band: band, in: app) }
        button.tap()
        XCTAssertEqual(button.value as? String, "All bands off")
        sleep(4)
        let silent = capture(app, named: "All-off-grayscale")
        assertGrayscale(pixels(silent, in: content))
        XCTAssertEqual(pixels(silent, in: mark.frame).coloredCount, 0, "All-off artwork must be exactly grayscale")
    }

    @MainActor
    func testAnimationLevelsPersistAndKeepAudioRunning() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-mixLevelsV2", "<dict><key>low</key><integer>4</integer><key>mid</key><integer>2</integer><key>high</key><integer>3</integer></dict>"]
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
        let diagnostic = app.staticTexts["audioDiagnostics"]
        let before = diagnostic.label.split(separator: ":").compactMap { UInt64($0) }
        let content = app.frame.insetBy(dx: 24, dy: 90)
        let background = CGRect(x: app.frame.minX + 2, y: app.frame.height * 0.52,
                                width: 18, height: app.frame.height * 0.38)
        let mark = app.otherElements["noiseColor"]
        let picker = app.segmentedControls["animationLevelPicker"]

        func choose(_ title: String) {
            app.buttons["settingsButton"].tap()
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            picker.buttons[title].tap()
            XCTAssertTrue(picker.buttons[title].isSelected)
            _ = capture(app, named: "Animation-settings-\(title)")
            app.buttons["Done"].tap()
        }

        choose("Med")
        sleep(4)
        let medium = capture(app, named: "Med-infinity-only")
        sleep(1)
        let mediumFlow = capture(app, named: "Med-infinity-flowing")
        XCTAssertEqual(pixels(medium, in: background).coloredCount, 0, "Med must hide background ribbons")
        XCTAssertGreaterThan(differences(pixels(medium, in: mark.frame), pixels(mediumFlow, in: mark.frame)), 1_000,
                             "Med must animate the infinity")

        choose("High")
        sleep(4)
        let high = capture(app, named: "High-ribbons")
        XCTAssertGreaterThan(pixels(high, in: background).coloredCount, 100, "High must add background ribbons")

        choose("Low")
        sleep(1)
        let first = capture(app, named: "Low-static-infinity")
        sleep(1)
        let second = capture(app, named: "Low-still")
        XCTAssertGreaterThan(pixels(first, in: mark.frame).coloredCount, 1_000, "Low keeps the infinity visible")
        XCTAssertEqual(differences(pixels(first, in: content), pixels(second, in: content), minimumChange: 0), 0)
        XCTAssertEqual(pixels(first, in: background).coloredCount, 0, "Low must hide background ribbons")
        XCTAssertEqual(app.buttons["playbackButton"].value as? String, "Playing continuously")
        self.choose(3, band: "mid", in: app) // Refresh the event-based audio counter snapshot.
        let after = diagnostic.label.split(separator: ":").compactMap { UInt64($0) }
        XCTAssertEqual(before.count, 2); XCTAssertEqual(after.count, 2)
        if before.count == 2 && after.count == 2 {
            XCTAssertEqual(before[0], after[0], "Visual levels must not restart the engine")
            XCTAssertGreaterThan(after[1], before[1] + 8_000)
        }

        // No animation launch argument masks the persisted selection.
        for (current, next) in [("Low", "High"), ("High", "Med"), ("Med", "Med")] {
            app.terminate(); app.launch()
            XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 15))
            app.buttons["settingsButton"].tap()
            XCTAssertTrue(picker.waitForExistence(timeout: 5))
            XCTAssertTrue(picker.buttons[current].isSelected, "\(current) must survive relaunch")
            picker.buttons[next].tap()
            app.buttons["Done"].tap()
        }
    }

    @MainActor
    private func choose(_ level: Int, band: String, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons["band-\(band)-\(level)"]
        button.tap()
        XCTAssertTrue(button.isSelected, file: file, line: line)
    }

    @MainActor
    func testButtonsShowOneSelectionAndGenerousTouchTargets() {
        let app = XCUIApplication()
        app.launchArguments = ["-mixLevelsV2", "<dict></dict>", "-mixLows", "2", "-mixMids", "2", "-mixHighs", "1", "-animationLevel", "low"]
        app.launch()
        XCTAssertTrue(app.buttons["band-low-3"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.sliders.count, 0)
        XCTAssertTrue(app.buttons["band-low-3"].isSelected)
        XCTAssertTrue(app.buttons["band-mid-3"].isSelected)
        XCTAssertTrue(app.buttons["band-high-2"].isSelected)
        _ = capture(app, named: "Six-buttons-preserved-favorite")
        for band in ["low", "mid", "high"] {
            for level in [5, 0, 1, 2] {
                let button = app.buttons["band-\(band)-\(level)"]
                XCTAssertGreaterThanOrEqual(button.frame.width, 44)
                XCTAssertGreaterThanOrEqual(button.frame.height, 56)
                XCTAssertTrue(app.frame.contains(button.frame), "Every touch target fits the screen")
                button.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.84)).tap()
                for candidate in 0...5 {
                    XCTAssertEqual(app.buttons["band-\(band)-\(candidate)"].isSelected, candidate == level)
                }
            }
        }
        choose(1, band: "high", in: app)
        XCTAssertTrue(app.buttons["band-high-1"].label.contains("-30 decibels"))
        _ = capture(app, named: "Six-buttons-trace-high")
        let target = app.buttons["band-mid-2"]
        let rim = CGRect(x: target.frame.minX + 5, y: target.frame.minY + 1,
                         width: target.frame.width - 10, height: 5)
        let selected = capture(app, named: "Glass-buttons-selected")
        choose(3, band: "mid", in: app)
        let unselected = capture(app, named: "Glass-selection-moved")
        XCTAssertGreaterThan(pixels(selected, in: rim).whiteCount,
                             pixels(unselected, in: rim).whiteCount + 30,
                             "A reflective selection rim must distinguish the active tile")
        let beforePause = app.staticTexts["audioDiagnostics"].label.split(separator: ":").compactMap { UInt64($0) }
        app.buttons["playbackButton"].tap()
        sleep(2)
        let paused = capture(app, named: "Six-buttons-paused")
        var pausedButtons = [UInt8]()
        for band in ["low", "mid", "high"] {
            for level in 0...5 {
                pausedButtons += pixels(paused, in: app.buttons["band-\(band)-\(level)"].frame).bytes
            }
        }
        // Apply the area tolerance to the whole control set. One native edge
        // pixel is a disproportionate fraction of a single tiny tile crop.
        assertGrayscale(Pixels(bytes: pausedButtons))
        app.terminate(); app.launchArguments = ["-animationLevel", "low"]; app.launch()
        XCTAssertTrue(app.buttons["band-high-1"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["band-high-1"].isSelected)
        XCTAssertTrue(app.buttons["band-mid-3"].isSelected)
        XCTAssertTrue(app.buttons["band-low-2"].isSelected)
        XCTAssertEqual(beforePause.first, 1, "Band changes must keep one engine instance")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, named name: String) -> UIImage {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return screenshot.image
    }

    private struct Pixels {
        let bytes: [UInt8]
        var whiteCount: Int {
            stride(from: 0, to: bytes.count, by: 4).filter { index in
                let rgb = bytes[index..<(index + 3)]
                return rgb.min()! > 210 && Int(rgb.max()!) - Int(rgb.min()!) < 12
            }.count
        }
        var maximumChannelSpread: Int {
            stride(from: 0, to: bytes.count, by: 4).map { index in
                let rgb = bytes[index..<(index + 3)]
                return Int(rgb.max()!) - Int(rgb.min()!)
            }.max() ?? 0
        }
        var greenCount: Int {
            var count = 0
            for i in stride(from: 0, to: bytes.count, by: 4) {
                let red = Int(bytes[i]), green = Int(bytes[i + 1]), blue = Int(bytes[i + 2])
                if green > red + 15 && green > blue + 10 { count += 1 }
            }
            return count
        }
        var hueCounts: [Int] {
            var counts = [Int](repeating: 0, count: 6)
            for index in stride(from: 0, to: bytes.count, by: 4) {
                let r = Double(bytes[index]) / 255, g = Double(bytes[index + 1]) / 255, b = Double(bytes[index + 2]) / 255
                let top = max(r, max(g, b)), bottom = min(r, min(g, b)), delta = top - bottom
                // Muted hues have lower absolute chroma than pure RGB. Require
                // meaningful relative saturation as well as a minimum signal.
                guard top > 0.14, delta > 0.035, delta / top > 0.16 else { continue }
                var hue: Double
                if top == r { hue = (g - b) / delta }
                else if top == g { hue = 2 + (b - r) / delta }
                else { hue = 4 + (r - g) / delta }
                hue = (hue * 60 + 360).truncatingRemainder(dividingBy: 360)
                counts[Int((hue + 30) / 60) % 6] += 1
            }
            return counts
        }
        var coloredCount: Int {
            stride(from: 0, to: bytes.count, by: 4).filter { index in
                let rgb = bytes[index..<(index + 3)]
                return Int(rgb.max()!) - Int(rgb.min()!) > 2
            }.count
        }
    }

    private func assertGrayscale(_ pixels: Pixels, file: StaticString = #filePath, line: UInt = #line) {
        // Native glass adds faint chromatic edge pixels even with saturation zero.
        // The fifteen-button capture has 21 such pixels (maximum spread 3/255)
        // among 2.2 million, all on native control edges. Bound the affected area
        // to 0.002% as well as its strength, independently of screenshot size.
        // The artwork itself is still required to be exactly grayscale above.
        let coloredFraction = Double(pixels.coloredCount) / Double(pixels.bytes.count / 4)
        XCTAssertLessThanOrEqual(coloredFraction, 0.00002, file: file, line: line)
        XCTAssertLessThanOrEqual(pixels.maximumChannelSpread, 6, file: file, line: line)
    }

    private func pixels(_ image: UIImage, in rect: CGRect) -> Pixels {
        let source = image.cgImage!
        let scale = CGFloat(source.width) / image.size.width
        let crop = source.cropping(to: CGRect(x: rect.minX * scale, y: rect.minY * scale,
                                              width: rect.width * scale, height: rect.height * scale))!
        var bytes = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: crop.width, height: crop.height,
                                    bitsPerComponent: 8, bytesPerRow: crop.width * 4,
                                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
        }
        return Pixels(bytes: bytes)
    }

    private func differences(_ first: Pixels, _ second: Pixels, minimumChange: Int = 2) -> Int {
        XCTAssertEqual(first.bytes.count, second.bytes.count)
        return zip(first.bytes, second.bytes).filter { abs(Int($0) - Int($1)) > minimumChange }.count
    }

    @MainActor
    func testLaunchPauseReopenAndBackground() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-animationLevel", "high", "-mixLevelsV2", "<dict><key>low</key><integer>4</integer><key>mid</key><integer>0</integer><key>high</key><integer>0</integer></dict>"]
        app.launch()
        let status = app.buttons["playbackButton"]
        XCTAssertTrue(status.waitForExistence(timeout: 15))
        let playing = NSPredicate(format: "value == %@", "Playing continuously")
        expectation(for: playing, evaluatedWith: status)
        waitForExpectations(timeout: 15)
        app.buttons["playbackButton"].tap()
        XCTAssertEqual(status.value as? String, "Paused")
        app.buttons["playbackButton"].tap()
        expectation(for: playing, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        let before = app.staticTexts["audioDiagnostics"].label.split(separator: ":").compactMap { UInt64($0) }
        XCTAssertEqual(before.count, 2)
        XCUIDevice.shared.press(.home)
        // This is a lifecycle smoke test, not an overnight acoustic test.
        sleep(15)
        app.activate()
        expectation(for: playing, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        let after = app.staticTexts["audioDiagnostics"].label.split(separator: ":").compactMap { UInt64($0) }
        XCTAssertEqual(after.count, 2)
        if before.count == 2 && after.count == 2 {
            XCTAssertEqual(before[0], after[0], "Backgrounding must not restart the engine")
            XCTAssertGreaterThan(after[1] - before[1], 8_000 * 14, "Audio must render continuously while backgrounded")
        }
        var selected = ["low": 4, "mid": 0, "high": 0]
        for band in ["low", "mid", "high"] {
            for level in 0..<6 {
                let cell = app.buttons["band-\(band)-\(level)"]
                XCTAssertTrue(cell.exists)
                XCTAssertGreaterThanOrEqual(cell.frame.width, 44)
                XCTAssertGreaterThanOrEqual(cell.frame.height, 56)
                choose(level, band: band, in: app)
                selected[band] = level
                XCTAssertEqual(status.value as? String, selected.values.allSatisfy { $0 == 0 } ? "All bands off" : "Playing continuously")
                for other in ["low", "mid", "high"] where other != band {
                    XCTAssertTrue(app.buttons["band-\(other)-\(selected[other]!)"].isSelected,
                                  "Changing one picker must preserve the other two")
                }
                let diagnostic = app.staticTexts["audioDiagnostics"].label.split(separator: ":")
                XCTAssertEqual(diagnostic.first, String(before[0])[...], "Band choices must not restart audio")
            }
        }
        XCTAssertEqual(app.staticTexts["noiseTitle"].label, "EverNoise")
        XCTAssertFalse(app.staticTexts["mixSummary"].exists)
        XCTAssertFalse(app.staticTexts["playbackStatus"].exists)
        XCTAssertEqual(app.sliders.count, 0)
        XCTAssertGreaterThanOrEqual(status.frame.width, 112)
        XCTAssertGreaterThanOrEqual(status.frame.height, 112)
        XCTAssertLessThan(app.buttons["band-high-5"].frame.midY, app.buttons["band-mid-5"].frame.midY)
        XCTAssertLessThan(app.buttons["band-mid-5"].frame.midY, app.buttons["band-low-5"].frame.midY)
        app.buttons["playbackButton"].tap()
        XCTAssertEqual(status.value as? String, "Paused")
        choose(0, band: "low", in: app)
        choose(3, band: "mid", in: app)
        choose(2, band: "high", in: app)
        XCTAssertEqual(status.value as? String, "Paused", "Choosing a balance must preserve a pause")
        XCUIDevice.shared.press(.home)
        app.activate()
        expectation(for: playing, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["noiseTitle"].waitForExistence(timeout: 15))
        for (band, level) in [("low", 0), ("mid", 3), ("high", 2)] {
            XCTAssertTrue(app.buttons["band-\(band)-\(level)"].isSelected,
                          "Remember all three bands, including a saved low zero")
        }
        choose(4, band: "low", in: app)
        choose(0, band: "mid", in: app)
        choose(0, band: "high", in: app)
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "EverNoise"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
