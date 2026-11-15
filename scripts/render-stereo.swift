// Production paired DSP through AVAudioEngine sample-rate/channel conversion.
// Usage: rate seconds low,mid,high|rapid|mute output.wav channels mono|stereo|switch|rapid
import AVFoundation
import Foundation

final class StereoAuditStream: @unchecked Sendable {
    let kind: BNSourceKind
    let pointer: OpaquePointer
    init(_ kind: BNSourceKind, _ leftSeed: UInt64, _ rightSeed: UInt64, _ level: Int, stereo: Bool) {
        self.kind = kind
        pointer = BNStereoCreateSource(kind, leftSeed, rightSeed, stereo)!
        BNStereoSetLevel(pointer, Int32(level)); BNStereoBeginFadeIn(pointer)
    }
    deinit { BNStereoDestroy(pointer) }
}
let args = CommandLine.arguments
let rate = Double(args[1])!, seconds = Double(args[2])!, preset = args[3], path = args[4]
let channels = AVAudioChannelCount(args[5])!, mode = args[6]
let coordinates = preset.split(separator: ",").compactMap { Int($0) }
let levels = coordinates.count == 3 ? coordinates : [4, 4, 4]
let initialStereo = mode == "stereo"
let streams = [
    StereoAuditStream(BNSourceBrown, 123456789, 1987654321, levels[0], stereo: initialStereo),
    StereoAuditStream(BNSourceMid, 987654321, 246813579, levels[1], stereo: initialStereo),
    StereoAuditStream(BNSourceGrayAir, 135792468, 975318642, levels[2], stereo: initialStereo)
]
let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
let engine = AVAudioEngine()
try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
for stream in streams {
    let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: BNRateForSource(stream.kind), channels: 2)!
    let source = AVAudioSourceNode(format: sourceFormat) { @Sendable [stream] silence, _, frames, buffers in
        silence.pointee = false
        BNStereoRenderAudioBuffers(stream.pointer, buffers, frames)
        return noErr
    }
    engine.attach(source)
    engine.connect(source, to: engine.mainMixerNode, format: sourceFormat)
}
engine.prepare(); try engine.start()
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
var settings = format.settings; settings[AVLinearPCMIsNonInterleaved] = false
var file: AVAudioFile? = try AVAudioFile(forWriting: URL(fileURLWithPath: path), settings: settings)
let total = Int64(rate * seconds), channelCount = Int(channels)
var frames: Int64 = 0, checked: Int64 = 0, transitions = 0, retries = 0
var peak = [Double](repeating: 0, count: channelCount), squares = peak, maxStep = peak, boundaryStep = peak
var previous = peak, minBlockRMS = [Double](repeating: 1, count: channelCount), cross = 0.0
var silentBlocks = [Int](repeating: 0, count: channelCount)
let rapid = preset == "rapid" || mode == "rapid"
let interval = rapid ? 0.037 : 2.5
var nextChange = Int64(rate * interval)
while frames < total {
    if frames >= nextChange {
        if mode == "switch" || mode == "rapid" {
            for stream in streams { BNStereoSetEnabled(stream.pointer, transitions.isMultiple(of: 2)) }
        }
        if preset == "rapid" || preset == "mute" {
            let cell = preset == "mute" ? (transitions.isMultiple(of: 2) ? 0 : 124) : (transitions * 37 + 62) % 125
            for (stream, level) in zip(streams, [cell / 25, (cell / 5) % 5, cell % 5]) {
                BNStereoSetLevel(stream.pointer, Int32(level))
            }
        }
        transitions += 1; nextChange = frames + Int64(rate * interval)
    }
    let requested = min(rapid ? 128 : 4096, total - frames)
    let status = try engine.renderOffline(AVAudioFrameCount(requested), to: buffer)
    guard status == .success else {
        retries += 1
        if retries > 100 { fatalError("Offline render stalled: \(status)") }
        continue
    }
    let data = buffer.floatChannelData!
    for ch in 0..<channelCount {
        var block = 0.0
        for n in 0..<Int(buffer.frameLength) {
            let x = Double(data[ch][n])
            guard x.isFinite, abs(x) < 0.959 else { fatalError("Clipping/invalid sample at \(frames + Int64(n))") }
            if mode == "mono", ch == 1 { precondition(data[0][n] == data[1][n], "Mono channels differ") }
            if frames > Int64(rate) {
                peak[ch] = max(peak[ch], abs(x)); squares[ch] += x * x; block += x * x
                let step = abs(x - previous[ch]); maxStep[ch] = max(maxStep[ch], step)
                if n == 0 { boundaryStep[ch] = max(boundaryStep[ch], step) }
            }
            previous[ch] = x
        }
        if frames > Int64(rate) {
            let rms = sqrt(block / Double(buffer.frameLength))
            minBlockRMS[ch] = min(minBlockRMS[ch], rms)
            if rms < 1e-8 { silentBlocks[ch] += 1 }
        }
    }
    if frames > Int64(rate) {
        if channels == 2 {
            for n in 0..<Int(buffer.frameLength) { cross += Double(data[0][n]) * Double(data[1][n]) }
        }
        checked += Int64(buffer.frameLength)
    }
    try file!.write(from: buffer); frames += Int64(buffer.frameLength)
}
file = nil; engine.stop()
let rms = squares.map { sqrt($0 / Double(checked)) }
let correlation = channels == 2 && squares[0] > 0 && squares[1] > 0 ? cross / sqrt(squares[0] * squares[1]) : 0
let result: [String: Any] = ["mix": preset, "mode": mode, "rate": rate, "channels": channels,
    "frames": frames, "rms": rms, "peak": peak, "maxStep": maxStep, "boundaryStep": boundaryStep,
    "minimumBlockRMS": minBlockRMS, "silentBlocks": silentBlocks, "renderRetries": retries,
    "modeAndMixIntervals": transitions, "correlation": correlation,
    "sourceFrames": streams.map { BNStereoRenderedFrames($0.pointer) }]
let json = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try json.write(to: URL(fileURLWithPath: path + ".json"))
let silent = levels.allSatisfy { $0 == 0 } || preset == "mute"
precondition(silent || (silentBlocks.allSatisfy { $0 == 0 } && rms.allSatisfy { $0 > 1e-6 }))
precondition(rms.allSatisfy { $0 < 0.07 })
if mode == "stereo", !silent, channels == 2 { precondition(abs(correlation) < 0.15) }
print("PASS \(preset) \(mode) \(rate)Hz \(channels)ch peak=\(peak) correlation=\(correlation)")
