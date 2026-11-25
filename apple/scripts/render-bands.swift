// Render independently selectable low/mid/high bands through Apple's
// real sample-rate converters. Build with the production DSP object/header.
import AVFoundation
import Foundation

final class Stream: @unchecked Sendable {
    let kind: BNSourceKind
    let pointer: OpaquePointer
    init(_ kind: BNSourceKind, _ seed: UInt64, _ level: Int) {
        self.kind = kind
        pointer = BNCreateSource(kind, seed, false)!
        BNSetLevel(pointer, Int32(level))
        BNBeginFadeIn(pointer)
    }
    deinit { BNDestroy(pointer) }
}
let args = CommandLine.arguments
let rate = Double(args[1])!
let seconds = Double(args[2])!
let preset = args[3]
let path = args[4]
let channels = args.count > 5 ? AVAudioChannelCount(args[5])! : 2
let coordinates = preset.split(separator: ",").compactMap { Int($0) }
let lows = coordinates.count == 3 ? coordinates[0] : 4
let mids = coordinates.count == 3 ? coordinates[1] : 0
let highs = coordinates.count == 3 ? coordinates[2] : 0
let streams = [
    Stream(BNSourceBrown, 123456789, lows),
    Stream(BNSourceMid, 987654321, mids),
    Stream(BNSourceGrayAir, 135792468, highs)
]
func select(_ index: Int) {
    // An intentionally broad walk, including long jumps in both axes.
    let cell = preset == "mute" ? (index % 2 == 0 ? 0 : 124) : (index * 37 + 62) % 125
    BNSetLevel(streams[0].pointer, Int32(cell / 25))
    BNSetLevel(streams[1].pointer, Int32((cell / 5) % 5))
    BNSetLevel(streams[2].pointer, Int32(cell % 5))
}
let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
let engine = AVAudioEngine()
try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
for stream in streams {
    let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: BNRateForSource(stream.kind), channels: 1)!
    let node = AVAudioSourceNode(format: sourceFormat) { @Sendable [stream] silence, _, frames, buffers in
        silence.pointee = false
        BNRenderAudioBuffers(stream.pointer, buffers, frames)
        return noErr
    }
    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: sourceFormat)
}
engine.prepare()
try engine.start()
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
var settings = format.settings
settings[AVLinearPCMIsNonInterleaved] = false
var file: AVAudioFile? = try AVAudioFile(forWriting: URL(fileURLWithPath: path), settings: settings)
let total = Int64(rate * seconds)
var frames: Int64 = 0, checked: Int64 = 0
var peak = 0.0, squares = 0.0, maxStep = 0.0, boundaryStep = 0.0
var minBlockRMS = 1.0, maxBlockRMS = 0.0
var previous: Float = 0
var silentBlocks = 0, retries = 0, transitions = 0
let interval = preset == "rapid" ? 0.037 : 1.5
var nextChange = Int64(rate * interval)
while frames < total {
    if (preset == "switch" || preset == "rapid" || preset == "mute"), frames >= nextChange {
        select(transitions)
        transitions += 1
        nextChange = frames + Int64(rate * interval)
    }
    let requested = min(preset == "rapid" ? 128 : 4096, total - frames)
    let status = try engine.renderOffline(AVAudioFrameCount(requested), to: buffer)
    guard status == .success else {
        retries += 1
        if retries > 100 { fatalError("Manual rendering stalled: \(status)") }
        continue
    }
    let data = buffer.floatChannelData!
    var blockSquares = 0.0
    for n in 0..<Int(buffer.frameLength) {
        let x = data[0][n]
        guard x.isFinite, abs(x) < 0.959, channels == 1 || x == data[1][n] else {
            fatalError("Clipping, invalid data or unequal channels at \(frames + Int64(n))")
        }
        if frames > Int64(rate) {
            peak = max(peak, Double(abs(x)))
            squares += Double(x) * Double(x)
            blockSquares += Double(x) * Double(x)
            let step = Double(abs(x - previous))
            maxStep = max(maxStep, step)
            if n == 0 { boundaryStep = max(boundaryStep, step) }
            checked += 1
        }
        previous = x
    }
    if frames > Int64(rate) {
        let rms = sqrt(blockSquares / Double(buffer.frameLength))
        minBlockRMS = min(minBlockRMS, rms)
        maxBlockRMS = max(maxBlockRMS, rms)
        if rms < 1e-8 { silentBlocks += 1 }
    }
    try file!.write(from: buffer)
    frames += Int64(buffer.frameLength)
}
file = nil
engine.stop()
let rms = sqrt(squares / Double(checked))
let result: [String: Any] = ["preset": preset, "lows": lows, "highs": highs, "mids": mids, "rate": rate, "channels": channels,
    "frames": frames, "rms": rms, "peak": peak, "max_step": maxStep,
    "boundary_step": boundaryStep, "min_block_rms": minBlockRMS,
    "max_block_rms": maxBlockRMS, "silent_blocks": silentBlocks,
    "render_retries": retries, "transitions": transitions,
    "source_frames": streams.map { BNRenderedFrames($0.pointer) }]
let json = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try json.write(to: URL(fileURLWithPath: path + ".json"))
FileHandle.standardOutput.write(json)
let intentionallySilent = (lows == 0 && mids == 0 && highs == 0) || preset == "mute"
guard (intentionallySilent || (silentBlocks == 0 && rms > 1e-6)), rms < 0.07 else { fatalError("Unexpected engine output") }
print("\nPASS")
