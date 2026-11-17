import CoreGraphics
import QuartzCore
import SpectrumAnalysis
import SwiftUI

struct SpectrogramSnapshot: @unchecked Sendable {
    // Immutable Core Graphics image, produced off the main/audio threads.
    let image: CGImage
    let columnTime: Double
    let endFrame: UInt64
}

private final class SpectrumWorkspace: @unchecked Sendable {
    let pointer = BNSpectrumCreate()
    deinit { if let pointer { BNSpectrumDestroy(pointer) } }
}

actor SpectrogramWorker {
    static let width = 513 // one extra column for continuous fractional scrolling
    static let height = Int(BNSpectrumRows)
    private weak var feed: OutputSampleFeed?
    private var workspace: SpectrumWorkspace?
    private var frames = [BNCapturedFrame](repeating: BNCapturedFrame(), count: 4096)
    private var columns = [Float](repeating: -160, count: 2 * Int(BNSpectrumRows))
    private var ends = [UInt64](repeating: 0, count: 2)
    private var pixels = [UInt8](repeating: 0, count: width * height * 4)
    private var column = 0
    private var originFrame: UInt64?
    private var originTime = 0.0
    private var lastEnd: UInt64 = 0
    private var lastInput: UInt64?
    private var started = false
    private let palette = SpectrogramPalette()

    init(feed: OutputSampleFeed) { self.feed = feed }

    func reset() {
        started = false; workspace = nil; originFrame = nil; lastInput = nil; lastEnd = 0
        column = 0
        pixels = [UInt8](repeating: 0, count: Self.width * Self.height * 4)
    }

    func poll() -> SpectrogramSnapshot? {
        guard let feed, let capture = feed.pointer else { return nil }
        if !started {
            workspace = SpectrumWorkspace()
            BNCaptureDiscard(capture)
            started = true
        }
        guard let spectrum = workspace?.pointer else { return nil }
        var changed = false
        for _ in 0..<16 { // bounded catch-up; graphics can never back-pressure audio
            if Task.isCancelled { return nil }
            let count = BNCaptureRead(capture, &frames, UInt32(frames.count))
            if count == 0 { break }
            if originFrame == nil || (lastInput != nil && frames[0].frame != lastInput! + 1) {
                originFrame = frames[0].frame
                originTime = CACurrentMediaTime() - Double(count-1)/48000
                pixels = [UInt8](repeating: 0, count: Self.width * Self.height * 4)
                column = 0
                BNSpectrumReset(spectrum)
            }
            lastInput = frames[Int(count)-1].frame
            let made = BNSpectrumConsume(spectrum, &frames, count, &columns, &ends, 2)
            for x in 0..<Int(made) {
                // Gaps inside a read are rare (consumer stall). Never join two
                // unrelated history segments or present them as continuous.
                if lastEnd > 0 && ends[x] != lastEnd + UInt64(BNSpectrumHop) {
                    pixels = [UInt8](repeating: 0, count: Self.width * Self.height * 4)
                    column = 0
                }
                for row in 0..<Self.height {
                    let dB = columns[x * Self.height + row]
                    let color = palette.encodedColor(row: row, decibels: dB)
                    let p = ((Self.height-1-row)*Self.width+column)*4
                    pixels[p] = color[0]; pixels[p+1] = color[1]; pixels[p+2] = color[2]; pixels[p+3] = 255
                }
                column = (column+1)%Self.width
                lastEnd = ends[x]; changed = true
            }
        }
        guard changed, let originFrame else { return nil }
        // Order the circular history into a small immutable image. All copying,
        // FFTs and color mapping happen here, never in the audio callback.
        var ordered = Data(count: pixels.count)
        ordered.withUnsafeMutableBytes { destination in
            pixels.withUnsafeBytes { source in
                for y in 0..<Self.height {
                    let row = y*Self.width*4, tail = (Self.width-column)*4
                    memcpy(destination.baseAddress!+row, source.baseAddress!+row+column*4, tail)
                    memcpy(destination.baseAddress!+row+tail, source.baseAddress!+row, column*4)
                }
            }
        }
        guard let provider = CGDataProvider(data: ordered as CFData),
              let image = CGImage(width: Self.width, height: Self.height, bitsPerComponent: 8,
                                  bitsPerPixel: 32, bytesPerRow: Self.width*4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        return SpectrogramSnapshot(image: image, columnTime: originTime + Double(lastEnd-originFrame)/48000,
                                   endFrame: lastEnd)
    }
}

@MainActor
struct SpectrogramView: View {
    let feed: OutputSampleFeed
    let isVisible: Bool
    let isSounding: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var snapshot: SpectrogramSnapshot?
    @State private var frozenTime: Double?
    private var active: Bool { isVisible && isSounding }
    private struct RunState: Equatable { let active: Bool; let reduced: Bool }
    #if os(tvOS)
    private let labelScale = 2.0
    #else
    private let labelScale = 1.0
    #endif
    private var accessibleValue: String {
        let description = isSounding
            ? "Live audio, 2 hertz to 24 kilohertz, axis extends to 48 kilohertz, 22 seconds of history. Red is low, green is mid, blue is high. Brighter means more power."
            : "Paused or silent"
        #if DEBUG
        return "\(description); frame=\(snapshot?.endFrame ?? 0)"
        #else
        return description
        #endif
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60,
                                paused: !active || reduceMotion || snapshot == nil)) { _ in
            Canvas { context, size in
                let plot = CGRect(x: 32*labelScale, y: 20*labelScale,
                                  width: max(1, size.width-40*labelScale), height: max(1, size.height-42*labelScale))
                if let snapshot {
                    var chart = context
                    chart.clip(to: Path(roundedRect: plot, cornerRadius: 10))
                    let displayTime = active ? CACurrentMediaTime() : (frozenTime ?? snapshot.columnTime)
                    let fraction = !reduceMotion
                        ? min(1, max(0, (displayTime-snapshot.columnTime)/(Double(BNSpectrumHop)/48000))) : 0
                    let pixel = plot.width/512
                    chart.draw(Image(decorative: snapshot.image, scale: 1),
                               in: CGRect(x: plot.minX-fraction*pixel, y: plot.minY,
                                          width: plot.width+pixel, height: plot.height))
                }
                func verticalFraction(_ frequency: Double) -> Double {
                    log(Double(BNSpectrumMaximumHz)/frequency) /
                        log(Double(BNSpectrumMaximumHz)/Double(BNSpectrumMinimumHz))
                }
                let limitY = plot.minY + plot.height*verticalFraction(Double(BNSpectrumNyquistHz))
                context.fill(Path(CGRect(x: plot.minX, y: plot.minY, width: plot.width, height: limitY-plot.minY)),
                             with: .color(.white.opacity(0.035)))
                var boundary = Path()
                boundary.move(to: CGPoint(x: plot.minX, y: limitY)); boundary.addLine(to: CGPoint(x: plot.maxX, y: limitY))
                context.stroke(boundary, with: .color(.white.opacity(0.2)),
                               style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                if snapshot == nil && active {
                    context.draw(Text("Measuring output…").font(.custom("AvenirNext-Regular", size: 11*labelScale))
                        .foregroundColor(.white.opacity(0.4)), at: CGPoint(x: plot.midX, y: plot.midY))
                }
                for (text, frequency) in [("48k", 48000.0), ("20k", 20000), ("2k", 2000), ("200", 200), ("20", 20), ("2", 2)] {
                    let fraction = verticalFraction(frequency)
                    let y = plot.minY+plot.height*fraction
                    var line = Path(); line.move(to: CGPoint(x: plot.minX, y: y)); line.addLine(to: CGPoint(x: plot.maxX, y: y))
                    context.stroke(line, with: .color(.white.opacity(0.09)), lineWidth: 0.5)
                    context.draw(Text(text).font(.custom("AvenirNext-Regular", size: 9*labelScale)).foregroundColor(.white.opacity(0.5)),
                                 at: CGPoint(x: plot.minX-6*labelScale, y: y), anchor: .trailing)
                }
                context.draw(Text("Hz").font(.custom("AvenirNext-Regular", size: 9*labelScale)).foregroundColor(.white.opacity(0.45)),
                             at: CGPoint(x: plot.minX-6*labelScale, y: 7*labelScale), anchor: .trailing)
                context.draw(Text("−120 … −30 dBFS/Hz · 24k limit").font(.custom("AvenirNext-Regular", size: 9*labelScale)).foregroundColor(.white.opacity(0.45)),
                             at: CGPoint(x: plot.minX, y: 7*labelScale), anchor: .leading)
                context.draw(Text("−22 s").font(.custom("AvenirNext-Regular", size: 9*labelScale)).foregroundColor(.white.opacity(0.45)),
                             at: CGPoint(x: plot.minX, y: plot.maxY+13*labelScale), anchor: .leading)
                context.draw(Text("Now").font(.custom("AvenirNext-Regular", size: 9*labelScale)).foregroundColor(.white.opacity(0.45)),
                             at: CGPoint(x: plot.maxX, y: plot.maxY+13*labelScale), anchor: .trailing)
            }
        }
        .saturation(isSounding ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Output spectrogram")
        .accessibilityValue(accessibleValue)
        .accessibilityIdentifier("outputSpectrogram")
        .onChange(of: active, initial: true) { _, enabled in
            frozenTime = enabled ? nil : CACurrentMediaTime()
            if !enabled { feed.stop() }
        }
        .onDisappear { feed.stop() }
        .task(id: RunState(active: active, reduced: reduceMotion), priority: .utility) {
            guard active else { return }
            snapshot = nil
            let lease = feed.begin()
            defer { feed.end(lease) }
            // One persistent actor serializes old/new sessions during rapid
            // toggles; the SPSC buffer never acquires a second consumer.
            let worker = feed.spectrumWorker
            await worker.reset()
            while !Task.isCancelled {
                if let next = await worker.poll(), !Task.isCancelled { snapshot = next }
                do { try await Task.sleep(for: .milliseconds(reduceMotion ? 1000 : 30)) } catch { return }
            }
        }
    }
}
