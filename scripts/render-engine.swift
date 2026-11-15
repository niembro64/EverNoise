// Actual AVAudioSourceNode -> main mixer -> hardware-format conversion, offline.
// Build with the production C object and BrownNoiseDSP.h as a bridging header.
import AVFoundation
import Foundation

final class Storage: @unchecked Sendable {
    let pointer = BNCreate(BNSourceSampleRate(), 123456789)!
    deinit { BNDestroy(pointer) }
}
let args = CommandLine.arguments
let rate = args.count > 1 ? Double(args[1])! : 48_000
let seconds = args.count > 2 ? Double(args[2])! : 120
let path = args.count > 3 ? args[3] : "build/audio-audit-v2/engine-48000.wav"
let channels = args.count > 4 ? AVAudioChannelCount(args[4])! : 2
let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: BNSourceSampleRate(), channels: 1)!
let engine = AVAudioEngine()
try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
let storage = Storage()
let source = AVAudioSourceNode(format: sourceFormat) { @Sendable [storage] silence, _, frames, buffers in
    silence.pointee = false
    BNRenderAudioBuffers(storage.pointer, buffers, frames)
    return noErr
}
engine.attach(source)
engine.connect(source, to: engine.mainMixerNode, format: sourceFormat)
engine.prepare()
try engine.start()
print("formats: source=\(source.outputFormat(forBus: 0)), mixer=\(engine.mainMixerNode.outputFormat(forBus: 0)), output=\(engine.outputNode.inputFormat(forBus: 0)), manual=\(engine.manualRenderingFormat)")
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
var fileSettings = format.settings
fileSettings[AVLinearPCMIsNonInterleaved] = false
var file: AVAudioFile? = try AVAudioFile(forWriting: URL(fileURLWithPath: path), settings: fileSettings)
var frames: Int64 = 0
var peak = 0.0, squares = 0.0, maxStep = 0.0, boundaryStep = 0.0
var previous: Float = 0
var checked: Int64 = 0
var silentBlocks = 0, retries = 0
let total = Int64(rate * seconds)
while frames < total {
    let count = AVAudioFrameCount(min(4096, total - frames))
    let status = try engine.renderOffline(count, to: buffer)
    guard status == .success else {
        retries += 1
        if retries > 100 { fatalError("Manual rendering stalled: \(status)") }
        continue
    }
    let data = buffer.floatChannelData!
    for n in 0..<Int(buffer.frameLength) {
        let x = data[0][n]
        guard x.isFinite, abs(x) < 0.75, channels == 1 || x == data[1][n] else {
            fatalError("Clipping, invalid data or unequal channels at \(frames + Int64(n))")
        }
        if frames > Int64(rate) {
            peak = max(peak, Double(abs(x)))
            squares += Double(x) * Double(x)
            let step = Double(abs(x - previous))
            maxStep = max(maxStep, step)
            if n == 0 { boundaryStep = max(boundaryStep, step) }
            checked += 1
        }
        previous = x
    }
    if frames > Int64(rate), (0..<Int(buffer.frameLength)).allSatisfy({ data[0][$0] == 0 }) { silentBlocks += 1 }
    try file!.write(from: buffer)
    frames += Int64(buffer.frameLength)
}
engine.stop()
file = nil // Finalize WAV length before the process exits (or a check fails).
let rms = sqrt(squares / Double(checked))
let report = "engine: rate=\(rate), frames=\(frames), source_frames=\(BNRenderedFrames(storage.pointer)), peak=\(peak), rms=\(rms), max_step=\(maxStep), boundary_step=\(boundaryStep), silent_blocks=\(silentBlocks), retries=\(retries)\n"
FileHandle.standardOutput.write(Data(report.utf8))
guard silentBlocks == 0, rms > 0.030, rms < 0.055 else { fatalError("Unexpected engine output") }
print("PASS")
