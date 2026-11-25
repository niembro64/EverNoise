import CoreGraphics
import SpectrumAnalysis
import XCTest
#if os(tvOS)
@testable import EverNoiseTV
#else
@testable import JustBrownNoise
#endif

final class SpectrogramWorkerTests: XCTestCase {
    @MainActor
    func testMaxAnalysisAndImageCreationKeepUpWithTheRunningAudioEngine() async throws {
        let driver = NoiseAudioDriver()
        let feed = driver.outputSamples
        defer { feed.stop(); driver.stop(immediately: true) }
        try driver.start()
        let engine = driver.currentEngine
        let capture = try XCTUnwrap(feed.pointer)
        _ = feed.begin()
        let worker = feed.spectrumWorker
        await worker.reset()
        let start = ContinuousClock.now, firstFrame = driver.renderedFrames
        var presentations = 0, lastEnd: UInt64 = 0
        var previousPresentation: ContinuousClock.Instant?, longestGap = Duration.zero
        while start.duration(to: .now) < .seconds(12) {
            if let snapshot = await worker.poll() {
                XCTAssertGreaterThan(snapshot.endFrame, lastEnd)
                lastEnd = snapshot.endFrame
                presentations += 1
                let now = ContinuousClock.now
                if let previousPresentation { longestGap = max(longestGap, previousPresentation.duration(to: now)) }
                previousPresentation = now
            }
            try await Task.sleep(for: .milliseconds(12))
        }
        // Snapshots batch several 60 Hz columns. Their count is not the
        // analysis or display refresh rate, especially in an unoptimized test.
        XCTAssertGreaterThan(presentations, 0)
        XCTAssertGreaterThan(lastEnd-firstFrame, 504_000)
        XCTAssertLessThan(driver.renderedFrames-lastEnd, 12_000)
        XCTAssertEqual(BNCaptureDroppedFrames(capture), 0)
        XCTAssertTrue(driver.isRunning && driver.currentEngine === engine)
        XCTAssertEqual(driver.startCount, 1)
        XCTAssertGreaterThan(driver.renderedFrames-firstFrame, 504_000)
        print("Max live engine: \(presentations) images in 12 s; \(driver.renderedFrames-firstFrame) audio frames; \(BNCaptureDroppedFrames(capture)) visual samples dropped; longest image gap \(longestGap)")
        feed.stop()
        await worker.reset()
    }

    func testSampleClockPresentationDoesNotJumpWhenColumnsArriveInBatches() {
        let time = 50.0, oldEndpoint = 49.95
        let oldOffset = SpectrogramPresentation.rightEdgeOffset(columnTime: oldEndpoint, displayTime: time)
        for count in 1...5 {
            let newEndpoint = oldEndpoint+Double(count)*SpectrogramPresentation.columnDuration
            let newOffset = SpectrogramPresentation.rightEdgeOffset(columnTime: newEndpoint, displayTime: time)
            XCTAssertEqual(newOffset-Double(count), oldOffset, accuracy: 1e-10)
        }
        let later = SpectrogramPresentation.rightEdgeOffset(columnTime: oldEndpoint, displayTime: time+1.0/120)
        XCTAssertEqual(oldOffset-later, 0.5, accuracy: 1e-10)
        XCTAssertEqual(SpectrogramPresentation.rightEdgeOffset(columnTime: oldEndpoint, displayTime: time+5), 0)
    }

    @MainActor
    func testWorkerCreatesRenderableLinearSixteenBitHistoryAndOffStopsCapture() async throws {
        let feed = OutputSampleFeed()
        let capture = try XCTUnwrap(feed.pointer)
        let worker = feed.spectrumWorker
        let lease = feed.begin()
        defer { feed.end(lease) }
        await worker.reset()
        _ = await worker.poll()
        var snapshot: SpectrogramSnapshot?
        var left = [Float](repeating: 0, count: 4096), right = left
        let blocks = (Int(BNSpectrumWarmupFrames)+Int(BNSpectrumHop)*8+4095)/4096
        for block in 0..<blocks {
            for n in 0..<4096 {
                let t = Double(block*4096+n)/48000
                left[n] = Float(0.1*sin(2*Double.pi*60*t)+0.03*sin(2*Double.pi*600*t)+0.01*sin(2*Double.pi*6000*t))
                right[n] = -left[n]
            }
            BNCapturePlanar(capture, &left, &right, 4096)
            if let next = await worker.poll() { snapshot = next }
        }
        let result = try XCTUnwrap(snapshot)
        XCTAssertEqual(result.image.bitsPerComponent, 16)
        XCTAssertEqual(result.image.bitsPerPixel, 64)
        XCTAssertEqual(result.image.width, SpectrogramPresentation.width)
        XCTAssertEqual(result.image.height, Int(BNSpectrumRows))
        XCTAssertEqual(result.image.colorSpace?.name, CGColorSpace.linearSRGB)
        XCTAssertGreaterThan(result.endFrame, UInt64(BNSpectrumWarmupFrames))
        // Decode through Core Graphics as the actual UI will, checking that
        // native byte order and the 64-bit RGBX layout produce real color.
        var pixels = [UInt8](repeating: 0, count: 64*256*4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: 64, height: 256,
            bitsPerComponent: 8, bytesPerRow: 64*4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let crop = try XCTUnwrap(result.image.cropping(to: CGRect(x: result.image.width-8, y: 0, width: 8, height: result.image.height)))
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 64, height: 256))
        XCTAssertGreaterThan(pixels.enumerated().filter { $0.offset % 4 != 3 && $0.element > 20 }.count, 100)
        XCTAssertEqual(BNCaptureDroppedFrames(capture), 0)
        feed.stop()
        let before = BNCapturePublishedFrames(capture)
        BNCapturePlanar(capture, &left, &right, 4096)
        XCTAssertEqual(BNCapturePublishedFrames(capture), before)
        await worker.reset()
    }
}
