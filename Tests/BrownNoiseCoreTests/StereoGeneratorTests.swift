import AVFoundation
import BrownNoiseDSP
import Testing

struct StereoGeneratorTests {
    private func pair(_ kind: BNSourceKind, stereo: Bool, level: Int = 4,
                      leftSeed: UInt64 = 123456789, rightSeed: UInt64 = 987654321) throws -> OpaquePointer {
        let p = try #require(BNStereoCreateSource(kind, leftSeed, rightSeed, stereo))
        BNStereoSetLevel(p, Int32(level)); BNStereoBeginFadeIn(p)
        return p
    }

    @Test(arguments: [BNSourceBrown, BNSourceMid, BNSourceGrayAir])
    func monoIsTheApprovedSignalAtEveryLevel(kind: BNSourceKind) throws {
        for level in 0...4 {
            let p = try pair(kind, stereo: false, level: level)
            let original = try #require(BNCreateSource(kind, 123456789, false))
            defer { BNStereoDestroy(p); BNDestroy(original) }
            BNSetLevel(original, Int32(level)); BNBeginFadeIn(original)
            let count = Int(BNRateForSource(kind) * 2)
            var left = [Float](repeating: 0, count: count), right = left, approved = left
            BNStereoRender(p, &left, &right, UInt32(count)); BNRenderMono(original, &approved, UInt32(count))
            #expect(left == approved)
            #expect(right == approved)
            #expect(BNStereoRenderedFrames(p) == UInt64(count))
        }
    }

    @Test(arguments: [BNSourceBrown, BNSourceMid, BNSourceGrayAir])
    func stereoUsesIndependentGeneratorsWithMatchingPower(kind: BNSourceKind) throws {
        let p = try pair(kind, stereo: true)
        let a = try #require(BNCreateSource(kind, 123456789, true))
        let b = try #require(BNCreateSource(kind, 987654321, true))
        defer { BNStereoDestroy(p); BNDestroy(a); BNDestroy(b) }
        let rate = Int(BNRateForSource(kind)), count = rate * 12
        var left = [Float](repeating: 0, count: count), right = left, expectedA = left, expectedB = left
        BNStereoRender(p, &left, &right, UInt32(count))
        BNRenderMono(a, &expectedA, UInt32(count)); BNRenderMono(b, &expectedB, UInt32(count))
        #expect(left == expectedA && right == expectedB)
        var aa = 0.0, bb = 0.0, ab = 0.0
        for i in rate..<count {
            let x = Double(left[i]), y = Double(right[i])
            aa += x * x; bb += y * y; ab += x * y
        }
        #expect(abs(ab / sqrt(aa * bb)) < 0.08)
        #expect(abs(10 * log10(aa / bb)) < 0.5)
    }

    @Test(arguments: [BNSourceBrown, BNSourceMid, BNSourceGrayAir])
    func modeChangesPreserveSequenceAndStayWithinBothSignals(kind: BNSourceKind) throws {
        let p = try pair(kind, stereo: false), reference = try pair(kind, stereo: true)
        defer { BNStereoDestroy(p); BNStereoDestroy(reference) }
        let rate = Int(BNRateForSource(kind))
        var l = [Float](repeating: 0, count: rate * 2), r = l, a = l, b = l
        BNStereoRender(p, &l, &r, UInt32(l.count)); BNStereoRender(reference, &a, &b, UInt32(l.count))
        for index in 0..<20 {
            BNStereoSetEnabled(p, index.isMultiple(of: 2))
            let count = 1 + (index * 137) % (rate / 3)
            BNStereoRender(p, &l, &r, UInt32(count)); BNStereoRender(reference, &a, &b, UInt32(count))
            #expect(l.prefix(count).elementsEqual(a.prefix(count)))
            #expect((0..<count).allSatisfy { r[$0].isFinite && r[$0] >= min(a[$0], b[$0]) && r[$0] <= max(a[$0], b[$0]) })
        }
        BNStereoSetEnabled(p, true)
        BNStereoRender(p, &l, &r, UInt32(l.count)); BNStereoRender(reference, &a, &b, UInt32(l.count))
        #expect(l == a && r.suffix(rate).elementsEqual(b.suffix(rate)))
        BNStereoSetEnabled(p, false)
        BNStereoRender(p, &l, &r, UInt32(l.count)); BNStereoRender(reference, &a, &b, UInt32(l.count))
        #expect(l == a && r.suffix(rate).elementsEqual(l.suffix(rate)))
        #expect(BNStereoRenderedFrames(p) == BNStereoRenderedFrames(reference))
    }

    @Test func rapidReversalDoesNotJumpAtTheCommand() throws {
        let a = try pair(BNSourceMid, stereo: false), b = try pair(BNSourceMid, stereo: false)
        defer { BNStereoDestroy(a); BNStereoDestroy(b) }
        var l = [Float](repeating: 0, count: 48000), r = l
        BNStereoRender(a, &l, &r, 48000); BNStereoRender(b, &l, &r, 48000)
        BNStereoSetEnabled(a, true); BNStereoSetEnabled(b, true)
        BNStereoRender(a, &l, &r, 13001); BNStereoRender(b, &l, &r, 13001)
        BNStereoSetEnabled(a, false)
        var al: Float = 0, ar: Float = 0, bl: Float = 0, br: Float = 0
        BNStereoRender(a, &al, &ar, 1); BNStereoRender(b, &bl, &br, 1)
        #expect(al == bl && ar == br)
    }

    @Test func stereoFadeIgnoresCallbackPartitioning() throws {
        let a = try pair(BNSourceBrown, stereo: false), b = try pair(BNSourceBrown, stereo: false)
        defer { BNStereoDestroy(a); BNStereoDestroy(b) }
        BNStereoSetEnabled(a, true); BNStereoSetEnabled(b, true)
        let count = 30001
        var al = [Float](repeating: 0, count: count), ar = al, bl = al, br = al
        BNStereoRender(a, &al, &ar, UInt32(count))
        bl.withUnsafeMutableBufferPointer { l in
            br.withUnsafeMutableBufferPointer { r in
                var offset = 0
                while offset < count {
                    let n = min(137, count - offset)
                    BNStereoRender(b, l.baseAddress! + offset, r.baseAddress! + offset, UInt32(n))
                    offset += n
                }
            }
        }
        #expect(al == bl && ar == br)
    }

    @Test(arguments: [false, true], [1, 2])
    func bufferLayoutPreservesChannelOrder(interleaved: Bool, channels: Int) throws {
        let p = try pair(BNSourceGrayAir, stereo: true), reference = try pair(BNSourceGrayAir, stereo: true)
        defer { BNStereoDestroy(p); BNStereoDestroy(reference) }
        let count: UInt32 = 23017
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000,
                                               channels: AVAudioChannelCount(channels), interleaved: interleaved))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count))
        buffer.frameLength = count
        BNStereoRenderAudioBuffers(p, buffer.mutableAudioBufferList, count)
        var l = [Float](repeating: 0, count: Int(count)), r = l
        BNStereoRender(reference, &l, &r, count)
        let list = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        for channel in 0..<channels {
            let data = list[interleaved ? 0 : channel].mData!.assumingMemoryBound(to: Float.self)
            let stride = interleaved ? channels : 1, offset = interleaved ? channel : 0
            let expected = channel == 0 ? l : r
            #expect((0..<Int(count)).allSatisfy { data[$0 * stride + offset] == expected[$0] })
        }
    }

    @Test func pauseAndRestartApplyTheNewModeWithoutResettingClocks() throws {
        let p = try pair(BNSourceBrown, stereo: true)
        defer { BNStereoDestroy(p) }
        var l = [Float](repeating: 0, count: 8000), r = l
        BNStereoRender(p, &l, &r, 8000)
        BNStereoSetPlaying(p, false); BNStereoRender(p, &l, &r, 8000)
        #expect(BNStereoIsSilent(p))
        #expect(l.suffix(4000).allSatisfy { $0 == 0 } && r.suffix(4000).allSatisfy { $0 == 0 })
        BNStereoSetEnabled(p, false); BNStereoSetLevel(p, 2); BNStereoBeginFadeIn(p)
        BNStereoRender(p, &l, &r, 8000)
        #expect(l == r && l[0] == 0 && l.suffix(100).contains { $0 != 0 })
        #expect(BNStereoRenderedFrames(p) == 24000)
    }

    @Test func duplicateSeedsAreSeparated() throws {
        for seed: UInt64 in [0, 123, 0xD1B54A32D192ED03] {
            let p = try pair(BNSourceMid, stereo: true, leftSeed: seed, rightSeed: seed)
            defer { BNStereoDestroy(p) }
            var l = [Float](repeating: 0, count: 48000), r = l
            BNStereoRender(p, &l, &r, 48000)
            #expect(l != r)
        }
        #expect(BNStereoCreateSource(BNSourceKind(rawValue: 99), 1, 2, false) == nil)
    }
}
