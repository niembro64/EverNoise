import BrownNoiseDSP
import Foundation
import SpectrumAnalysis
import Testing

struct SpectrumTests {
    private let size = Int(BNSpectrumFFTSize)
    private let warmup = Int(BNSpectrumWarmupFrames)
    private let delay = Int(BNSpectrumFilterDelay)

    private func analyze(gain: Float = 0.5, rightGain: Float = -0.5, bin: Int = 683) throws -> ([Float], [Float]) {
        let analyzer = try #require(BNSpectrumCreate())
        defer { BNSpectrumDestroy(analyzer) }
        var frames = (0..<warmup).map { n in
            let sample = Float(sin(2 * Double.pi * Double(bin*n) / Double(size)))
            return BNCapturedFrame(left: gain*sample, right: rightGain*sample, frame: UInt64(n))
        }
        var column = [Float](repeating: 0, count: Int(BNSpectrumRows))
        var end: UInt64 = 0
        #expect(BNSpectrumConsume(analyzer, &frames, UInt32(warmup), &column, &end, 1) == 1)
        #expect(end == UInt64(warmup-1-delay))
        var power = [Float](repeating: 0, count: size/2+1)
        BNSpectrumCopyPower(analyzer, &power)
        return (power, column)
    }

    @Test func calibratedPowerAndFrequencyDoNotCancelOppositePhaseStereo() throws {
        let (power, column) = try analyze()
        let integrated = power.reduce(0.0) { $0 + Double($1) } * 48000 / Double(size)
        #expect(abs(integrated - 0.125) < 1e-5, "PSD integrates to the actual stereo mean-square power")
        #expect(power.indices.max(by: { power[$0] < power[$1] }) == 683)
        #expect(column.enumerated().allSatisfy {
            BNSpectrumRowFrequency(UInt32($0.offset)) <= 24000 ? $0.element.isFinite : $0.element.isNaN
        })
        let (singleChannel, _) = try analyze(rightGain: 0)
        #expect(abs(singleChannel[683]/power[683] - 0.5) < 1e-6)
        let (quieter, _) = try analyze(gain: 0.25, rightGain: -0.25)
        #expect(abs(10*log10(quieter[683]/power[683]) + 6.0206) < 0.001)
    }

    @Test func lowAndHighFrequencyResolutionAndSilenceAreMeasured() throws {
        for bin in [14, 68, 1365, 12288, 16383] { // 20.5 Hz through the last bin below Nyquist
            let (power, _) = try analyze(bin: bin)
            #expect(power.indices.max(by: { power[$0] < power[$1] }) == bin)
        }
        let (power, column) = try analyze(gain: 0, rightGain: 0)
        #expect(power.allSatisfy { $0 == 0 })
        #expect(column.enumerated().allSatisfy {
            BNSpectrumRowFrequency(UInt32($0.offset)) <= 24000 ? $0.element == -200 : $0.element.isNaN
        })
    }

    @Test func twoHertzResolutionRejectsHighFrequencyAliases() throws {
        let analyzer = try #require(BNSpectrumCreate())
        defer { BNSpectrumDestroy(analyzer) }
        let frequency = 11 * 6000.0 / Double(size) // 2.014 Hz, on a long-window bin
        func measure(_ hz: Double) -> [Float] {
            BNSpectrumReset(analyzer)
            var frames = (0..<warmup).map { n in
                let value = Float(0.5*sin(2*Double.pi*hz*Double(n)/48000))
                return BNCapturedFrame(left: value, right: -value, frame: UInt64(n))
            }
            var column = [Float](repeating: 0, count: Int(BNSpectrumRows)), end: UInt64 = 0
            #expect(BNSpectrumConsume(analyzer, &frames, UInt32(warmup), &column, &end, 1) == 1)
            var power = [Float](repeating: 0, count: size/2+1)
            BNSpectrumCopyLowPower(analyzer, &power)
            return power
        }
        let low = measure(frequency)
        #expect(low.indices.max(by: { low[$0] < low[$1] }) == 11)
        let integrated = low.reduce(0.0) { $0+Double($1) }*6000/Double(size)
        #expect(abs(integrated-0.125) < 1e-5)
        let alias = measure(6000+frequency)
        #expect(alias[11] < low[11]*1e-11, "Decimation must not invent bass from treble")
    }

    @Test func referenceColorsFollowEqualGainPowerComplementarity() {
        for f in [2.0, 20, 100, 200, 600, 2000, 10000, 23999] {
            var weights = [Double](repeating: 0, count: 3)
            BNSpectrumReferenceWeights(f, &weights)
            let w = tan(Double.pi*f/48000)
            let low = 1/(1+pow(w/tan(Double.pi*200/48000), 4))
            let mid = (1-low)/(1+pow(w/tan(Double.pi*2000/48000), 4))
            for (actual, expected) in zip(weights, [low, mid, 1-low-mid]) {
                #expect(abs(actual-expected) < 1e-10)
            }
            #expect(abs(weights.reduce(0,+)-1) < 1e-12)
        }
        #expect(BNSpectrumRowFrequency(0) == 2)
        #expect(abs(BNSpectrumRowFrequency(UInt32(BNSpectrumRows-1))-48000) < 1e-7)
    }

    @Test func offCapturesNothingAndFullBufferNeverOverwritesUnreadSamples() throws {
        let capture = try #require(BNCaptureCreate())
        defer { BNCaptureDestroy(capture) }
        var left = (0..<Int(BNCaptureCapacity)).map { Float($0) }
        var right = left.map { -$0 }
        BNCapturePlanar(capture, &left, &right, 100)
        #expect(BNCapturePublishedFrames(capture) == 0)
        BNCaptureSetEnabled(capture, true)
        BNCapturePlanar(capture, &left, &right, UInt32(left.count))
        BNCapturePlanar(capture, &left, &right, 1000)
        #expect(BNCaptureDroppedFrames(capture) == 1000)
        var copied = [BNCapturedFrame](repeating: BNCapturedFrame(), count: left.count)
        #expect(BNCaptureRead(capture, &copied, UInt32(copied.count)) == BNCaptureCapacity)
        #expect(copied.enumerated().allSatisfy { $0.element.left == left[$0.offset] && $0.element.right == right[$0.offset] })
        #expect(copied[0].frame == 100)
        BNCaptureSetEnabled(capture, false)
        BNCapturePlanar(capture, &left, &right, 100)
        #expect(BNCaptureRead(capture, &copied, UInt32(copied.count)) == 0)
    }

    @Test func captureIsBitIdenticalToFinalOutputAndCannotChangeTheSound() throws {
        let a = try #require(BNMixCreate(398924)), b = try #require(BNMixCreate(398924))
        let capture = try #require(BNCaptureCreate())
        defer { BNMixDestroy(a); BNMixDestroy(b); BNCaptureDestroy(capture) }
        var left = [Float](repeating: 0, count: 4096), right = left, expectedL = left, expectedR = left
        var samples = [BNCapturedFrame](repeating: BNCapturedFrame(), count: 4096)
        for block in 0..<80 {
            BNCaptureSetEnabled(capture, block.isMultiple(of: 2))
            BNMixRender(a, &left, &right, 4096); BNMixRender(b, &expectedL, &expectedR, 4096)
            BNCapturePlanar(capture, &left, &right, 4096)
            #expect(left == expectedL && right == expectedR)
            let count = BNCaptureRead(capture, &samples, 4096)
            #expect(count == (block.isMultiple(of: 2) ? 4096 : 0))
            if count > 0 { #expect(samples.enumerated().allSatisfy { $0.element.left == left[$0.offset] && $0.element.right == right[$0.offset] }) }
        }
    }

    @Test func missingSamplesResetTheFFTWindowAndOverlapUsesExactSampleTime() throws {
        let analyzer = try #require(BNSpectrumCreate())
        defer { BNSpectrumDestroy(analyzer) }
        var frames = (0..<warmup).map { BNCapturedFrame(left: 0.1, right: 0.1, frame: UInt64($0)) }
        var columns = [Float](repeating: 0, count: Int(BNSpectrumRows)*2), ends = [UInt64](repeating: 0, count: 2)
        #expect(BNSpectrumConsume(analyzer, &frames, UInt32(warmup), &columns, &ends, 2) == 1)
        let hop = Int(BNSpectrumHop)
        frames = (0..<2*hop).map { BNCapturedFrame(left: 0.1, right: 0.1, frame: UInt64(warmup+$0)) }
        #expect(BNSpectrumConsume(analyzer, &frames, UInt32(2*hop), &columns, &ends, 2) == 2)
        #expect(ends == [UInt64(warmup+hop-1-delay), UInt64(warmup+2*hop-1-delay)])
        frames = (0..<4096).map { BNCapturedFrame(left: 0, right: 0, frame: UInt64(warmup+9999+$0)) }
        #expect(BNSpectrumConsume(analyzer, &frames, 4096, &columns, &ends, 2) == 0,
                "A dropped or disabled interval must not be spliced into a false spectrum")
    }
}
