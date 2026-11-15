import SwiftUI

struct InfinityBounds: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// One opaque linear-light canvas composites the infinity, mist and all four
/// background ribbons before one explicit sRGB output encoding. Native controls
/// stay outside this surface so Liquid Glass retains its live backdrop.
struct RibbonArtwork: View {
    let frame: FluidMotion.Frame
    let infinityRect: CGRect
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let height = max(1, geometry.size.height)
            // Approximately the same total pixel budget as build 16's two
            // surfaces. Only shader coordinates move; raster dimensions stay fixed.
            let pixelWidth = min(width * displayScale, width < 600 ? 768 : 1024)
            let rasterWidth = pixelWidth / max(1, displayScale)
            Rectangle().fill(.black)
                .visualEffect { view, raster in
                    view.colorEffect(ShaderLibrary.livingRibbon(
                        .float2(raster.size), .float(frame.phase), .float(frame.activity),
                        .float3(frame.color.x, frame.color.y, frame.color.z),
                        .float3(frame.bandPower.x, frame.bandPower.y, frame.bandPower.z),
                        .float(3), .float(0), .float2(geometry.size),
                        .float3(NoisePalette.linearHues[0].x, NoisePalette.linearHues[0].y, NoisePalette.linearHues[0].z),
                        .float3(NoisePalette.linearHues[1].x, NoisePalette.linearHues[1].y, NoisePalette.linearHues[1].z),
                        .float3(NoisePalette.linearHues[2].x, NoisePalette.linearHues[2].y, NoisePalette.linearHues[2].z),
                        .float3(NoisePalette.linearHues[3].x, NoisePalette.linearHues[3].y, NoisePalette.linearHues[3].z),
                        .float3(NoisePalette.linearHues[4].x, NoisePalette.linearHues[4].y, NoisePalette.linearHues[4].z),
                        .float3(NoisePalette.linearHues[5].x, NoisePalette.linearHues[5].y, NoisePalette.linearHues[5].z),
                        .float4(infinityRect.minX, infinityRect.minY, infinityRect.width, infinityRect.height),
                        .float(frame.ambience)))
                }
                .frame(width: rasterWidth, height: height * rasterWidth / width)
                // The shader has already encoded the completed opaque image.
                // Explicit output avoids implicit shader/group color conversions.
                .drawingGroup(opaque: true, colorMode: .nonLinear)
                .scaleEffect(width / rasterWidth, anchor: .topLeading)
                .frame(width: width, height: height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
