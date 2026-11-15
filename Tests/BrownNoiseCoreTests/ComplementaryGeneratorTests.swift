import BrownNoiseDSP
import Foundation
import Testing

struct ComplementaryGeneratorTests {
    private let kinds = [BNSourceComplementaryLow, BNSourceComplementaryMid, BNSourceComplementaryHigh]

    @Test func allSourcesUseTheSameClockAndPreserveSamplesAcrossBufferSizes() throws {
        for kind in kinds {
            #expect(BNRateForSource(kind) == 48000)
            let a = try #require(BNCreateSource(kind, 87364219, true))
            let b = try #require(BNCreateSource(kind, 87364219, true))
            defer { BNDestroy(a); BNDestroy(b) }
            let count = 144013
            var whole = [Float](repeating: 0, count: count), partitioned = whole
            BNRenderMono(a, &whole, UInt32(count))
            partitioned.withUnsafeMutableBufferPointer { buffer in
                var offset = 0
                while offset < count {
                    let n = min(1 + (offset * 37 % 2048), count - offset)
                    BNRenderMono(b, buffer.baseAddress! + offset, UInt32(n))
                    offset += n
                }
            }
            #expect(whole == partitioned)
            #expect(BNRenderedFrames(a) == UInt64(count))
        }
    }

    @Test func newBandsKeepExactSilenceAndTheSameLogarithmicLevels() throws {
        let gains = [0.0, pow(10,-18.0/20), pow(10,-12.0/20), pow(10,-6.0/20), 1.0]
        for kind in kinds {
            let reference = try #require(BNCreateSource(kind, 2317127, true))
            defer { BNDestroy(reference) }
            var expected = [Float](repeating: 0, count: 96000)
            BNRenderMono(reference, &expected, 96000)
            for level in 0...4 {
                let p = try #require(BNCreateSource(kind, 2317127, true))
                defer { BNDestroy(p) }
                BNSetLevel(p, Int32(level)); BNBeginFadeIn(p)
                var actual = [Float](repeating: 0, count: expected.count)
                BNRenderMono(p, &actual, UInt32(actual.count))
                let error = zip(actual, expected).map { abs(Double($0)-Double($1)*gains[level]) }.max()!
                #expect(error < 1e-8)
                if level == 0 { #expect(actual.allSatisfy { $0 == 0 }) }
                else { #expect(actual.suffix(48000).contains { $0 != 0 }) }
            }
        }
    }

    @Test func levelRetargetingDoesNotResetTheFilterOrJumpOnTheFirstSample() throws {
        for kind in kinds {
            let a = try #require(BNCreateSource(kind, 6297183, true))
            let b = try #require(BNCreateSource(kind, 6297183, true))
            defer { BNDestroy(a); BNDestroy(b) }
            var warmup = [Float](repeating: 0, count: 96000)
            BNRenderMono(a, &warmup, 96000); BNRenderMono(b, &warmup, 96000)
            BNSetLevel(a, 0)
            var x: Float = 0, y: Float = 0
            BNRenderMono(a, &x, 1); BNRenderMono(b, &y, 1)
            #expect(x == y)
            #expect(BNRenderedFrames(a) == 96001)
            BNRenderMono(a, &warmup, 96000)
            #expect(warmup.suffix(48000).allSatisfy { $0 == 0 })
            BNSetLevel(a, 4)
            BNRenderMono(a, &x, 1)
            #expect(x == 0)
            BNRenderMono(a, &warmup, 96000)
            #expect(warmup.suffix(48000).contains { $0 != 0 })
        }
    }
}
