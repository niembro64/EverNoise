import XCTest
import SpectrumAnalysis
#if os(tvOS)
@testable import EverNoiseTV
#else
@testable import JustBrownNoise
#endif

final class SpectrogramPaletteTests: XCTestCase {
    func testEqualMeasuredPowerHasEqualLightnessAndAllColorsFitTheDisplay() {
        let palette = SpectrogramPalette()
        for db in stride(from: Float(-100), through: 30, by: 3) {
            let expectedY = SpectrogramPalette.luminance(palette.linearColor(row: 0, decibels: db))
            for row in 0..<Int(BNSpectrumRows) {
                let rgb = palette.linearColor(row: row, decibels: db)
                XCTAssertEqual(SpectrogramPalette.luminance(rgb), expectedY, accuracy: 1e-12)
                for channel in 0..<3 { XCTAssertTrue((0...1).contains(rgb[channel])) }
            }
        }
    }

    func testFixedPerceptualCurveIsMonotonicAndDoesNotClipBrightDetail() {
        var previous = -1.0
        for db in stride(from: Float(-100), through: 30, by: 0.25) {
            let lightness = SpectrogramPalette.lightness(decibels: db)
            XCTAssertGreaterThan(lightness, previous)
            XCTAssertLessThan(lightness, 70)
            previous = lightness
        }
        // Undo the soft shoulder: a 10 dB increase doubles the contrast proxy,
        // including the subtracted display floor. This is not an SPL meter.
        func proxy(_ db: Float) -> Double {
            let lightness = SpectrogramPalette.lightness(decibels: db)
            return lightness/(70-lightness) + exp2(Double(SpectrogramPalette.floorDB-SpectrogramPalette.referenceDB)/10)
        }
        XCTAssertEqual(proxy(-40)/proxy(-50), 2, accuracy: 1e-12)
        XCTAssertEqual(SpectrogramPalette.lightness(decibels: -200), 0)
    }

    func testSixteenBitIntermediatePreservesFineGradients() {
        let palette = SpectrogramPalette()
        let colors = (0..<1000).map { palette.linearColor16(row: 100, decibels: -40 + Float($0)/1000) }
        let distinct = Set(colors.map { "\($0.x),\($0.y),\($0.z)" })
        let encoded = (0..<1000).map { palette.encodedColor(row: 100, decibels: -40 + Float($0)/1000) }
        let eightBitCount = Set(encoded.map { "\($0.x),\($0.y),\($0.z)" }).count
        XCTAssertGreaterThan(distinct.count, eightBitCount*50,
                             "A one-decibel gradient must preserve far more detail than the old 8-bit intermediate")
    }

    func testBrighterPowerPreservesFrequencyHueAndUnknownValuesAreBlack() {
        let palette = SpectrogramPalette()
        for row in 0..<Int(BNSpectrumRows) {
            let dim = palette.linearColor(row: row, decibels: -90)
            let bright = palette.linearColor(row: row, decibels: -40)
            XCTAssertGreaterThan(SpectrogramPalette.luminance(bright), SpectrogramPalette.luminance(dim))
            for channel in 1..<3 { XCTAssertEqual(dim[channel]/dim[0], bright[channel]/bright[0], accuracy: 1e-12) }
            XCTAssertEqual(palette.encodedColor(row: row, decibels: .nan), .zero)
            XCTAssertEqual(palette.encodedColor(row: row, decibels: -200), .zero)
        }
        func color(at frequency: Double) -> SIMD3<Double> {
            let row = Int((log(frequency/2)/log(24000)*Double(BNSpectrumRows-1)).rounded())
            return palette.linearColor(row: row, decibels: -60)
        }
        let low = color(at: 20), mid = color(at: 600), high = color(at: 10000)
        XCTAssertGreaterThan(low.x, max(low.y, low.z))
        XCTAssertGreaterThan(mid.y, max(mid.x, mid.z))
        XCTAssertGreaterThan(high.z, max(high.x, high.y))
    }
}
