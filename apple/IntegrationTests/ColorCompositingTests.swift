import XCTest
import SwiftUI
import UIKit
import PlaybackCore
@testable import JustBrownNoise

final class ColorCompositingTests: XCTestCase {
    func testExactSRGBReferenceValuesAndRoundTrips() {
        XCTAssertEqual(LinearLight.decode(0.5), 0.21404114048223255, accuracy: 1e-14)
        XCTAssertEqual(LinearLight.encode(0.5), 0.7353569830524495, accuracy: 1e-14)
        XCTAssertEqual(LinearLight.decode(0.04045), 0.0031308049535603713, accuracy: 1e-14)
        for v in [-0.5, 0, 0.001, 0.03, 0.1, 0.5, 1, 1.5] {
            XCTAssertEqual(LinearLight.encode(LinearLight.decode(v)), v, accuracy: 1e-12)
        }
    }

    func testBandLightAddsByPowerWithoutGammaSpaceAveraging() {
        let low = RibbonPalette(mix: NoiseMix(highs: 0, mids: 0, lows: 5)).mixedColor
        let high = RibbonPalette(mix: NoiseMix(highs: 5, mids: 0, lows: 0)).mixedColor
        let both = RibbonPalette(mix: NoiseMix(highs: 5, mids: 0, lows: 5)).mixedColor
        XCTAssertEqual(both, low + high)
        let quiet = RibbonPalette(mix: NoiseMix(highs: 0, mids: 0, lows: 1)).mixedColor
        XCTAssertEqual(quiet.x / low.x, pow(10, -3.0), accuracy: 1e-14)
        XCTAssertEqual(NoisePalette.linearHues.count, 6)
    }

    @MainActor
    func testSwiftUILinearCompositingProducesCorrectDisplayValue() throws {
        // The production renderer composites inside Metal, then returns an
        // opaque encoded pixel through this exact colorEffect/drawingGroup path.
        // Probe that boundary independently of the ribbon's artistic shading.
        let shader = Shader(function: ShaderFunction(library: .bundle(Bundle(for: Self.self)),
                                                      name: "linearHalfProbe"), arguments: [])
        let view = Color.black.colorEffect(shader)
            .frame(width: 16, height: 16).drawingGroup(opaque: true, colorMode: .nonLinear)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        for value in pixel.prefix(3) { XCTAssertEqual(Int(value), 188, accuracy: 2) }
        XCTAssertEqual(pixel[3], 255)
    }

    @MainActor
    func testAvenirNextFacesArePresentAndScaleWithAccessibilityText() throws {
        for name in ["AvenirNext-UltraLight", "AvenirNext-Regular", "AvenirNext-Medium", "AvenirNext-DemiBold"] {
            let base = try XCTUnwrap(UIFont(name: name, size: 17), "No silent font fallback: \(name)")
            let scaled = UIFontMetrics(forTextStyle: .body).scaledFont(for: base,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge))
            XCTAssertGreaterThan(scaled.pointSize, base.pointSize)
        }
    }
}
