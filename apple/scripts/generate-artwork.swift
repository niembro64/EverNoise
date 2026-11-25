// Code-drawn artwork; no external assets or dependencies.
// Run from the repository root: swift scripts/generate-artwork.swift
import AppKit

let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
// A single continuous infinity ribbon blends low/red, mid/green, high/blue.
// Geometry matches the small color indicator in the app; no lettering makes
// the mark independent of the final product name.
let path = CGMutablePath()
for step in 0...720 {
    let t = Double(step) / 720 * 2 * Double.pi
    let denominator = 1 + pow(cos(t), 2)
    let point = CGPoint(x: 512 + 350 * sin(t) / denominator,
                        y: 512 + 570 * sin(t) * cos(t) / denominator)
    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
}
path.closeSubpath()
context.addPath(path)
context.setLineWidth(74)
context.setLineCap(.round)
context.setLineJoin(.round)
context.replacePathWithStrokedPath()
context.clip()
let colors = [CGColor(red: 0.90, green: 0.22, blue: 0.25, alpha: 1),
              CGColor(red: 0.28, green: 0.72, blue: 0.48, alpha: 1),
              CGColor(red: 0.25, green: 0.43, blue: 0.92, alpha: 1)]
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                          colors: colors as CFArray, locations: [0, 0.5, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 150, y: 512),
                           end: CGPoint(x: 874, y: 512), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let data = bitmap.representation(using: .png, properties: [:])!
for path in ["App/Assets.xcassets/AppIcon.appiconset/AppIcon.png", "App/Assets.xcassets/NowPlayingArtwork.imageset/Artwork.png"] {
    try data.write(to: URL(fileURLWithPath: path))
}
