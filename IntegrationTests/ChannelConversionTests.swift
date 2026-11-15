import AVFoundation
import BrownNoiseDSP
import XCTest
@testable import JustBrownNoise

@MainActor
final class ChannelConversionTests: XCTestCase {
    private final class Probe: @unchecked Sendable {
        let pointer: OpaquePointer
        let paired: Bool
        init(paired: Bool) {
            self.paired = paired
            pointer = paired ? BNStereoCreateSource(BNSourceBrown, 123456789, 987654321, false)! : BNCreateSource(BNSourceBrown, 123456789, true)!
            if paired { BNStereoSetLevel(pointer, 4); BNStereoBeginFadeIn(pointer) }
        }
        deinit { if paired { BNStereoDestroy(pointer) } else { BNDestroy(pointer) } }
    }
    private func render(rate: Double, paired: Bool) throws -> [Float] {
        let engine = AVAudioEngine(), stream = Probe(paired: paired)
        let output = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
        try engine.enableManualRenderingMode(.offline, format: output, maximumFrameCount: 4096)
        let input = AVAudioFormat(standardFormatWithSampleRate: 8000, channels: paired ? 2 : 1)!
        let source = AVAudioSourceNode(format: input) { @Sendable [stream] silence, _, count, buffers in
            silence.pointee = false
            if stream.paired { BNStereoRenderAudioBuffers(stream.pointer, buffers, count) }
            else { BNRenderAudioBuffers(stream.pointer, buffers, count) }
            return noErr
        }
        engine.attach(source); engine.connect(source, to: engine.mainMixerNode, format: input)
        engine.prepare(); try engine.start(); defer { engine.stop() }
        let buffer = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: 4096)!
        var samples = [Float]()
        for _ in 0..<24 {
            XCTAssertEqual(try engine.renderOffline(4096, to: buffer), .success)
            samples.append(contentsOf: UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
        }
        return samples
    }
    func testMonoSpectrumAndExplicitConversionGain() throws {
        for rate in [16000.0, 44100, 48000, 96000] {
            let old = try render(rate: rate, paired: false), new = try render(rate: rate, paired: true)
            let gain = zip(old, new).reduce(0.0) { $0 + Double($1.0) * Double($1.1) } / old.reduce(0.0) { $0 + Double($1) * Double($1) }
            print("IOS_MONO_COMPATIBILITY rate=\(rate) gain=\(gain)")
            // Apple's legacy mono SRC path applies -3.0103 dB at 44.1 kHz.
            // A permanent two-channel path preserves the calibrated source gain
            // consistently instead. This is an explicit release compatibility
            // difference, not a reason to add route-specific gain guesses to
            // production or change the graph when the Stereo switch changes.
            let expectedGain = rate == 44100 ? sqrt(2.0) : 1.0
            XCTAssertEqual(gain, expectedGain, accuracy: 1e-6)
            let residual = zip(old, new).map { abs(Double($0) * expectedGain - Double($1)) }.max()!
            XCTAssertLessThan(residual, 1e-6, "Conversion must not reshape the signal")
            XCTAssertLessThan(new.map { abs($0) }.max()!, 0.3)
            if rate != 44100 { XCTAssertEqual(old, new) }
        }
    }
}
