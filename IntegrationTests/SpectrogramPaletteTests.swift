import XCTest
import SpectrumAnalysis
@testable import JustBrownNoise

final class SpectrogramPaletteTests: XCTestCase {
    func testEqualMeasuredPowerHasEqualLightnessAndAllColorsFitTheDisplay() {
        let palette = SpectrogramPalette()
        for db in stride(from: Float(-120), through: -30, by: 3) {
            let expectedY = SpectrogramPalette.luminance(palette.linearColor(row: 0, decibels: db))
            for row in 0..<Int(BNSpectrumRows) {
                let rgb = palette.linearColor(row: row, decibels: db)
                XCTAssertEqual(SpectrogramPalette.luminance(rgb), expectedY, accuracy: 1e-12)
                for channel in 0..<3 { XCTAssertTrue((0...1).contains(rgb[channel])) }
            }
        }
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
