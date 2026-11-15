// Code-drawn infinity artwork for tvOS layered icons and Top Shelf.
// Run from the repository root: swift scripts/generate-tv-artwork.swift
import AppKit

let root = URL(fileURLWithPath: "TVApp/Assets.xcassets")
let brand = root.appendingPathComponent("App Icon & Top Shelf Image.brandassets")
let info: [String: Any] = ["author": "xcode", "version": 1]

func json(_ value: [String: Any], at directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent("Contents.json"))
}

func render(width: Int, height: Int, background: Bool, ribbon: Bool, title: Bool = false, to url: URL) throws {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    if background {
        context.setFillColor(CGColor(red: 0.008, green: 0.009, blue: 0.013, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
    if ribbon {
        let amplitude = min(Double(width) * 0.37, Double(height) * (title ? 0.54 : 0.72))
        let centerY = Double(height) * (title ? 0.64 : 0.5)
        let path = CGMutablePath()
        for step in 0...1440 {
            let t = Double(step) / 1440 * 2 * Double.pi
            let denominator = 1 + sin(t) * sin(t)
            let p = CGPoint(x: Double(width) * 0.5 + amplitude * cos(t) / denominator,
                            y: centerY + amplitude * sin(t) * cos(t) / denominator)
            if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        context.saveGState()
        context.addPath(path)
        context.setLineWidth(Double(height) * 0.08)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.replacePathWithStrokedPath()
        context.clip()
        let colors = [CGColor(red: 0.680, green: 0.423, blue: 0.401, alpha: 1),
                      CGColor(red: 0.373, green: 0.556, blue: 0.378, alpha: 1),
                      CGColor(red: 0.405, green: 0.499, blue: 0.704, alpha: 1)]
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: colors as CFArray, locations: [0, 0.5, 1])!
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: Double(width) * 0.5 - amplitude, y: centerY),
                                   end: CGPoint(x: Double(width) * 0.5 + amplitude, y: centerY), options: [])
        context.restoreGState()
    }
    if title {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        for (text, size, y) in [("EverNoise", 0.105, 0.20), ("Your sound. All night.", 0.04, 0.12)] {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: "AvenirNext-UltraLight", size: Double(height) * size)!,
                .foregroundColor: NSColor(white: 0.82, alpha: 1)]
            let string = NSAttributedString(string: text, attributes: attributes)
            string.draw(at: NSPoint(x: (Double(width) - Double(string.size().width)) / 2, y: Double(height) * y))
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

try json(["info": info], at: root)
var assets: [[String: Any]] = []
for (name, width, height, scales) in [("App Icon", 400, 240, [1, 2]), ("App Store Icon", 1280, 768, [1])] {
    let stack = brand.appendingPathComponent("\(name).imagestack")
    try json(["info": info, "layers": [["filename": "Ribbon.imagestacklayer"], ["filename": "Background.imagestacklayer"]]], at: stack)
    for layer in ["Ribbon", "Background"] {
        let layerURL = stack.appendingPathComponent("\(layer).imagestacklayer")
        let images = layerURL.appendingPathComponent("Content.imageset")
        try json(["info": info], at: layerURL)
        try json(["info": info, "images": scales.map { ["idiom": "tv", "scale": "\($0)x", "filename": "Artwork@\($0)x.png"] }], at: images)
        for scale in scales {
            try render(width: width * scale, height: height * scale,
                       background: layer == "Background", ribbon: layer == "Ribbon",
                       to: images.appendingPathComponent("Artwork@\(scale)x.png"))
        }
    }
    assets.append(["size": "\(width)x\(height)", "idiom": "tv", "filename": "\(name).imagestack", "role": "primary-app-icon"])
}
for (name, width, role) in [("Top Shelf", 1920, "top-shelf-image"), ("Top Shelf Wide", 2320, "top-shelf-image-wide")] {
    let images = brand.appendingPathComponent("\(name).imageset")
    try json(["info": info, "images": [1, 2].map { ["idiom": "tv", "scale": "\($0)x", "filename": "Artwork@\($0)x.png"] }], at: images)
    for scale in [1, 2] {
        try render(width: width * scale, height: 720 * scale, background: true, ribbon: true, title: true,
                   to: images.appendingPathComponent("Artwork@\(scale)x.png"))
    }
    assets.append(["size": "\(width)x720", "idiom": "tv", "filename": "\(name).imageset", "role": role])
}
try json(["info": info, "assets": assets], at: brand)
