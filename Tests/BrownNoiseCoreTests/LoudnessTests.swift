import BrownNoiseDSP
import Foundation
import PlaybackCore
import Testing

struct LoudnessTests {
    private func create(_ low: Int32 = 2, _ mid: Int32 = 2, _ high: Int32 = 1, offset: Int32 = 0) throws -> OpaquePointer {
        let g = try #require(BNMixCreate(923847))
        BNMixSetLevels(g, low, mid, high); BNMixSetOffsetDB(g, offset); BNMixBeginFadeIn(g)
        return g
    }
    private func render(_ g: OpaquePointer, _ n: Int) -> ([Float], [Float]) {
        var l = [Float](repeating: 0, count: n), r = l
        BNMixRender(g, &l, &r, UInt32(n)); return (l, r)
    }

    @Test func bufferPartitioningDoesNotChangeAudioOrCorrection() throws {
        let a = try create(), b = try create()
        defer { BNMixDestroy(a); BNMixDestroy(b) }
        let n = 190013, expected = render(a, n)
        var l = [Float](repeating: 0, count: n), r = l
        l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
            var offset = 0
            while offset < n {
                let count = min(n-offset, 1+(offset*37)%2048)
                BNMixRender(b, lp.baseAddress!+offset, rp.baseAddress!+offset, UInt32(count))
                offset += count
            }
        } }
        #expect(l == expected.0 && r == expected.1)
        #expect(BNMixRenderedFrames(a) == UInt64(n))
        #expect(BNMixReadMetrics(a).slowGain == BNMixReadMetrics(b).slowGain)
    }

    @Test func proportionalWeightsPreserveTheSameSoundAndVolume() throws {
        let a = try create(1, 2, 3), b = try create(2, 3, 4)
        defer { BNMixDestroy(a); BNMixDestroy(b) }
        let x = render(a, 96000), y = render(b, 96000)
        #expect(zip(x.0, y.0).map { abs($0-$1) }.max()! < 1e-7)
        #expect(zip(x.1, y.1).map { abs($0-$1) }.max()! < 1e-7)
    }

    @Test func silentMixAndPauseStaySilentWithoutGainWindup() throws {
        let g = try create(0, 0, 0)
        defer { BNMixDestroy(g) }
        let silence = render(g, 48000)
        #expect(silence.0.allSatisfy { $0 == 0 } && silence.1.allSatisfy { $0 == 0 })
        #expect(BNMixReadMetrics(g).slowGain == 1)
        BNMixSetLevels(g, 2, 2, 1)
        #expect(render(g, 1).0[0] == 0)
        #expect(render(g, 96000).0.suffix(48000).contains { $0 != 0 })
        BNMixSetPlaying(g, false)
        let paused = render(g, 9600)
        #expect(paused.0.suffix(4800).allSatisfy { $0 == 0 })
        #expect(BNMixIsSilent(g))
        let gain = BNMixReadMetrics(g).slowGain
        _ = render(g, 48000)
        #expect(BNMixReadMetrics(g).slowGain == gain)
        BNMixSetOffsetDB(g, 3); BNMixSetStereo(g, false); BNMixBeginFadeIn(g)
        let resumed = render(g, 96000)
        #expect(resumed.0 == resumed.1)
        #expect(resumed.0.suffix(48000).contains { $0 != 0 })
        BNMixSetLevels(g, 0, 0, 0)
        #expect(render(g, 96000).0.suffix(48000).allSatisfy { $0 == 0 })
    }

    @Test func offsetAppliesInDecibelsAndControlsClamp() throws {
        let a = try create(), b = try create(offset: -6), c = try create(offset: 99), d = try create(offset: 3)
        defer { for g in [a,b,c,d] { BNMixDestroy(g) } }
        let x = render(a, 96000), y = render(b, 96000)
        let ratio = Float(pow(10, -6.0/20))
        #expect(zip(x.0, y.0).map { abs($1-$0*ratio) }.max()! < 1e-7)
        #expect(render(c, 96000).0 == render(d, 96000).0)
        #expect(VolumeOffset.clamp(Int.min) == -18)
        #expect(VolumeOffset.clamp(Int.max) == 3)
    }

    @Test func controlChangesAreContinuousOnTheFirstSample() throws {
        let a = try create(), b = try create()
        defer { BNMixDestroy(a); BNMixDestroy(b) }
        _ = render(a, 96000); _ = render(b, 96000)
        BNMixSetLevels(a, 4, 0, 0); BNMixSetStereo(a, false); BNMixSetOffsetDB(a, 3)
        #expect(render(a, 1).0 == render(b, 1).0)
        for i in 0..<40 {
            BNMixSetLevels(a, Int32(i%5), Int32((i/5)%5), Int32((i/25)%5))
            BNMixSetOffsetDB(a, i.isMultiple(of: 2) ? -18 : 3)
            BNMixSetStereo(a, i.isMultiple(of: 3))
            let x = render(a, 1776)
            #expect((x.0+x.1).allSatisfy { $0.isFinite && abs($0) < 0.708 })
        }
        #expect(BNMixRenderedFrames(a) == 96001+40*1776)
    }
}
