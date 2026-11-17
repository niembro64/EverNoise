// Production normalized output through Apple's sample-rate/channel conversion.
// Arguments: outputRate seconds low,mid,high offsetDB channels stereo|mono|rapid path.wav
import AVFoundation
import Foundation

final class LoudnessAuditStream: @unchecked Sendable {
    let pointer: OpaquePointer
    init(levels: [Int], offset: Int, stereo: Bool) {
        pointer = BNMixCreate(198273465)!
        BNMixSetLevels(pointer, Int32(levels[0]), Int32(levels[1]), Int32(levels[2]))
        BNMixSetOffsetDB(pointer, Int32(offset)); BNMixSetStereo(pointer, stereo)
        BNMixBeginFadeIn(pointer)
    }
    deinit { BNMixDestroy(pointer) }
}
let args = CommandLine.arguments
let rate = Double(args[1])!, seconds = Double(args[2])!
let levels = args[3].split(separator: ",").map { Int($0)! }, offset = Int(args[4])!
let channels = AVAudioChannelCount(args[5])!, mode = args[6], path = args[7]
let stream = LoudnessAuditStream(levels: levels, offset: offset, stereo: mode != "mono")
let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
let engine = AVAudioEngine()
try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
let input = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
let source = AVAudioSourceNode(format: input) { @Sendable [stream] silence, _, count, buffers in
    silence.pointee = false
    BNMixRenderAudioBuffers(stream.pointer, buffers, count)
    return noErr
}
engine.attach(source); engine.connect(source, to: engine.mainMixerNode, format: input)
engine.prepare(); try engine.start()
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
var settings = format.settings; settings[AVLinearPCMIsNonInterleaved] = false
var file: AVAudioFile? = try AVAudioFile(forWriting: URL(fileURLWithPath: path), settings: settings)
var rendered: Int64 = 0, retries = 0, changes = 0, nextChange = Int64(rate*0.037)
let total = Int64(rate*seconds)
while rendered < total {
    if mode == "rapid", rendered >= nextChange {
        let cell = (changes * 37) % 124 + 1
        BNMixSetLevels(stream.pointer, Int32(cell/25), Int32((cell/5)%5), Int32(cell%5))
        BNMixSetOffsetDB(stream.pointer, changes.isMultiple(of: 2) ? -6 : 3)
        BNMixSetStereo(stream.pointer, changes.isMultiple(of: 3))
        changes += 1; nextChange = rendered + Int64(rate*0.037)
    }
    let count = min(mode == "rapid" ? 128 : 4096, total-rendered)
    guard try engine.renderOffline(AVAudioFrameCount(count), to: buffer) == .success else {
        retries += 1; precondition(retries < 100); continue
    }
    for ch in 0..<Int(channels) {
        for n in 0..<Int(buffer.frameLength) {
            let x = buffer.floatChannelData![ch][n]
            precondition(x.isFinite && abs(x) < 0.794329, "Post-conversion peak overload")
            if mode == "mono", ch == 1 { precondition(x == buffer.floatChannelData![0][n]) }
        }
    }
    try file!.write(from: buffer); rendered += Int64(buffer.frameLength)
}
file = nil; engine.stop()
print("PASS \(rate) Hz \(channels)ch \(args[3]) \(offset)dB \(mode) \(rendered) frames")
