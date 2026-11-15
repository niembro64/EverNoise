import BrownNoiseDSP
import AudioToolbox
import Foundation
import Testing

struct GeneratorTests {
    @Test func brownSourceAPIKeepsTheApprovedSequence() throws {
        let original = try #require(BNCreate(8_000, 123456789))
        let source = try #require(BNCreateSource(BNSourceBrown, 123456789, true))
        defer { BNDestroy(original); BNDestroy(source) }
        var a = [Float](repeating: 0, count: 100_000)
        var b = a
        BNRenderMono(original, &a, UInt32(a.count))
        BNRenderMono(source, &b, UInt32(b.count))
        #expect(a == b)
    }

    @Test(arguments: [0, 1, 2, 3])
    func sourceSelectionFadesWhilePreservingItsClock(index: Int) throws {
        let kinds = [BNSourceBrown, BNSourceWhite, BNSourceGrayAir, BNSourceMid]
        let kind = kinds[index]
        let rate = Int(BNRateForSource(kind))
        let generator = try #require(BNCreateSource(kind, 147, false))
        defer { BNDestroy(generator) }
        var samples = [Float](repeating: 0, count: rate)
        BNRenderMono(generator, &samples, UInt32(rate))
        #expect(samples.allSatisfy { $0 == 0 })
        #expect(BNRenderedFrames(generator) == UInt64(rate))
        BNSetSelected(generator, true)
        BNRenderMono(generator, &samples, UInt32(rate))
        #expect(samples[0] == 0)
        let stable = samples.dropFirst(rate * 3 / 5)
        let rms = sqrt(stable.reduce(0.0) { $0 + Double($1 * $1) } / Double(stable.count))
        #expect(rms > (index == 0 ? 0.03 : 0.009))
        let bounds: [Float] = [0.75, 0.02, 0.109, 0.10]
        #expect(samples.allSatisfy { $0.isFinite && abs($0) <= bounds[index] })
        BNSetSelected(generator, false)
        BNRenderMono(generator, &samples, UInt32(rate))
        #expect(samples.dropFirst(rate * 3 / 5).allSatisfy { $0 == 0 })
        #expect(BNRenderedFrames(generator) == UInt64(rate * 3))
    }

    @Test func rapidSelectionReversalHasNoGainJump() throws {
        let a = try #require(BNCreateSource(BNSourceWhite, 81, true))
        let b = try #require(BNCreateSource(BNSourceWhite, 81, true))
        defer { BNDestroy(a); BNDestroy(b) }
        var buffer = [Float](repeating: 0, count: 48_000)
        BNRenderMono(a, &buffer, 48_000); BNRenderMono(b, &buffer, 48_000)
        BNSetSelected(a, false); BNSetSelected(b, false)
        BNRenderMono(a, &buffer, 8_000); BNRenderMono(b, &buffer, 8_000)
        BNSetSelected(a, true)
        var changed: Float = 0, unchanged: Float = 0
        BNRenderMono(a, &changed, 1); BNRenderMono(b, &unchanged, 1)
        #expect(changed == unchanged)
    }

    @Test func restartAppliesSelectionMadeWhileStopped() throws {
        let generator = try #require(BNCreateSource(BNSourceWhite, 92, true))
        defer { BNDestroy(generator) }
        var buffer = [Float](repeating: 0, count: 48_000)
        BNRenderMono(generator, &buffer, 48_000)
        BNSetSelected(generator, false)
        BNBeginFadeIn(generator)
        BNRenderMono(generator, &buffer, 48_000)
        #expect(buffer.allSatisfy { $0 == 0 })
        BNSetSelected(generator, true)
        BNBeginFadeIn(generator)
        BNRenderMono(generator, &buffer, 48_000)
        #expect(buffer[0] == 0)
        #expect(buffer.suffix(100).contains { $0 != 0 })
    }

    @Test(arguments: [1, 2, 3])
    func wideSourcesIgnoreCallbackPartitioning(index: Int) throws {
        let kind = [BNSourceWhite, BNSourceGrayAir, BNSourceMid][index - 1]
        let a = try #require(BNCreateSource(kind, 718, true))
        let b = try #require(BNCreateSource(kind, 718, true))
        defer { BNDestroy(a); BNDestroy(b) }
        var whole = [Float](repeating: 0, count: 100_000)
        var chunks = whole
        BNRenderMono(a, &whole, UInt32(whole.count))
        chunks.withUnsafeMutableBufferPointer { p in
            var offset = 0
            while offset < p.count {
                let count = min(137, p.count - offset)
                BNRenderMono(b, p.baseAddress! + offset, UInt32(count))
                offset += count
            }
        }
        #expect(whole == chunks)
    }

    @Test(arguments: [BNSourceBrown, BNSourceMid, BNSourceGrayAir], [false, true])
    func bandLevelsHaveEqualDecibelStepsOnStartupAndWhilePlaying(kind: BNSourceKind, startup: Bool) throws {
        var previousDB: Double?
        for level in 0...4 {
            let a = try #require(BNCreateSource(kind, 714, true))
            let b = try #require(BNCreateSource(kind, 714, true))
            defer { BNDestroy(a); BNDestroy(b) }
            let count = Int(BNRateForSource(kind))
            let stableCount = count / 5
            var actual = [Float](repeating: 0, count: count)
            var full = actual
            if startup {
                BNSetLevel(a, Int32(level))
                BNBeginFadeIn(a)
            }
            BNRenderMono(a, &actual, UInt32(count)); BNRenderMono(b, &full, UInt32(count))
            if !startup {
                BNSetLevel(a, Int32(level))
                BNRenderMono(a, &actual, UInt32(count)); BNRenderMono(b, &full, UInt32(count))
                #expect(actual[0] == full[0], "A new target starts at the current gain")
            }
            // Measure the emitted power after both startup and selection fades.
            // The reference has the same random/filter history at full gain.
            let actualPower = actual.suffix(stableCount).reduce(0.0) { $0 + Double($1) * Double($1) }
            let fullPower = full.suffix(stableCount).reduce(0.0) { $0 + Double($1) * Double($1) }
            let expectedDB = Double(level - 4) * 6
            let scale = level == 0 ? Float(0) : Float(pow(10, expectedDB / 20))
            if level == 0 {
                #expect(actualPower == 0, "Zero must mute the layer exactly")
            } else {
                let measuredDB = 10 * log10(actualPower / fullPower)
                #expect(abs(measuredDB - expectedDB) < 1e-5)
                if let previousDB { #expect(abs(measuredDB - previousDB - 6) < 1e-5) }
                previousDB = measuredDB
            }
            for index in (count - stableCount)..<count {
                #expect(abs(actual[index] - full[index] * scale) < 1e-8)
            }
            #expect(BNRenderedFrames(a) == BNRenderedFrames(b))
        }
    }

    @Test func fractionalLevelReversalAndClampingAreContinuous() throws {
        let a = try #require(BNCreateSource(BNSourceMid, 72, true))
        let b = try #require(BNCreateSource(BNSourceMid, 72, true))
        defer { BNDestroy(a); BNDestroy(b) }
        var buffer = [Float](repeating: 0, count: 48_000)
        BNRenderMono(a, &buffer, 48_000); BNRenderMono(b, &buffer, 48_000)
        BNSetLevel(a, 1); BNSetLevel(b, 1)
        BNRenderMono(a, &buffer, 7000); BNRenderMono(b, &buffer, 7000)
        BNSetLevel(a, 3)
        var changed: Float = 0, continuing: Float = 0
        BNRenderMono(a, &changed, 1); BNRenderMono(b, &continuing, 1)
        #expect(changed == continuing)
        BNSetLevel(a, -1); BNBeginFadeIn(a)
        BNRenderMono(a, &buffer, 48_000)
        #expect(buffer.allSatisfy { $0 == 0 })
        BNSetLevel(a, 99); BNBeginFadeIn(a)
        BNRenderMono(a, &buffer, 48_000)
        #expect(buffer.allSatisfy { abs($0) <= 0.10 })
        #expect(buffer.suffix(100).contains { $0 != 0 })
    }

    @Test func outputIsIdenticalAcrossArbitraryCallbackBoundaries() throws {
        let a = try #require(BNCreate(48_000, 12345))
        let b = try #require(BNCreate(48_000, 12345))
        defer { BNDestroy(a); BNDestroy(b) }
        var whole = [Float](repeating: 0, count: 200_000)
        var chunks = whole
        BNRenderMono(a, &whole, UInt32(whole.count))
        chunks.withUnsafeMutableBufferPointer { buffer in
            var offset = 0
            for size in [1, 17, 128, 511, 1024, 4096, 7, 8192, 186_024] {
                let count = min(size, buffer.count - offset)
                BNRenderMono(b, buffer.baseAddress! + offset, UInt32(count))
                offset += count
            }
            if offset < buffer.count { BNRenderMono(b, buffer.baseAddress! + offset, UInt32(buffer.count - offset)) }
        }
        #expect(whole == chunks)
    }

    @Test(arguments: [8_000.0, 44_100, 48_000, 96_000, 384_000])
    func signalIsFiniteCenteredAndBounded(sampleRate: Double) throws {
        let generator = try #require(BNCreate(sampleRate, 42))
        defer { BNDestroy(generator) }
        var samples = [Float](repeating: 0, count: Int(sampleRate * 8))
        BNRenderMono(generator, &samples, UInt32(samples.count))
        let stable = samples.dropFirst(Int(sampleRate))
        #expect(stable.allSatisfy { $0.isFinite && abs($0) <= 0.75 })
        let mean = stable.reduce(0.0) { $0 + Double($1) } / Double(stable.count)
        let rms = sqrt(stable.reduce(0.0) { $0 + Double($1 * $1) } / Double(stable.count))
        #expect(abs(mean) < 0.01)
        // The app uses the fixed 8 kHz source. Static bounded gain at other
        // rates gives less noise power per hertz, without any level adaptation.
        let normalized = rms * sqrt(sampleRate / BNSourceSampleRate())
        #expect(normalized > 0.035 && normalized < 0.055)
        #expect(samples[0] == 0)
        #expect(samples.prefix(100).map(abs).max()! < 0.01)
    }

    @Test func freshSeedsProduceDifferentAudio() throws {
        let a = try #require(BNCreate(48_000, 1))
        let b = try #require(BNCreate(48_000, 2))
        defer { BNDestroy(a); BNDestroy(b) }
        var first = [Float](repeating: 0, count: 2048)
        var second = first
        BNRenderMono(a, &first, 2048)
        BNRenderMono(b, &second, 2048)
        #expect(first != second)
    }

    @Test func invalidFormatsFailBeforeRendering() {
        for rate in [0.0, -1, Double.nan, Double.infinity, 400_000] {
            #expect(BNCreate(rate, 42) == nil)
        }
    }

    @Test func pauseFadesToZeroAndResumePreservesTheNoiseSequence() throws {
        let rate = BNSourceSampleRate()
        let a = try #require(BNCreate(rate, 981))
        let reference = try #require(BNCreate(rate, 981))
        defer { BNDestroy(a); BNDestroy(reference) }
        var sound = [Float](repeating: 0, count: 8000)
        var full = sound
        BNRenderMono(a, &sound, 8000)
        BNRenderMono(reference, &full, 8000)
        #expect(sound == full)
        BNSetPlaying(a, false)
        BNRenderMono(a, &sound, 8000)
        BNRenderMono(reference, &full, 8000)
        #expect(sound[0] == full[0], "Pause must not jump to zero at a block boundary")
        #expect(sound.dropFirst(640).allSatisfy { $0 == 0 })
        #expect(BNIsSilent(a))
        BNSetPlaying(a, true)
        BNRenderMono(a, &sound, 8000)
        BNRenderMono(reference, &full, 8000)
        #expect(sound[0] == 0)
        #expect(Array(sound.dropFirst(2000)) == Array(full.dropFirst(2000)))
        #expect(!BNIsSilent(a))
        #expect(BNRenderedFrames(a) == 24_000)
    }

    @Test func rapidResumeReversesFadeWithoutAJump() throws {
        let a = try #require(BNCreate(BNSourceSampleRate(), 81))
        let b = try #require(BNCreate(BNSourceSampleRate(), 81))
        defer { BNDestroy(a); BNDestroy(b) }
        var warm = [Float](repeating: 0, count: 8000)
        BNRenderMono(a, &warm, 8000)
        BNRenderMono(b, &warm, 8000)
        BNSetPlaying(a, false); BNSetPlaying(b, false)
        BNRenderMono(a, &warm, 100); BNRenderMono(b, &warm, 100)
        BNSetPlaying(a, true)
        var resumed: Float = 0
        var stillFading: Float = 0
        BNRenderMono(a, &resumed, 1); BNRenderMono(b, &stillFading, 1)
        #expect(resumed == stillFading, "Changing direction must start at the current gain")
    }

    @Test func interleavedStereoDuplicatesMonoWithoutOverwritingBuffers() throws {
        let mono = try #require(BNCreate(BNSourceSampleRate(), 117))
        let stereo = try #require(BNCreate(BNSourceSampleRate(), 117))
        defer { BNDestroy(mono); BNDestroy(stereo) }
        let count = 16_000
        var reference = [Float](repeating: 0, count: count)
        BNRenderMono(mono, &reference, UInt32(count))
        var padded = [Float](repeating: 1234, count: count * 2 + 16)
        padded.withUnsafeMutableBufferPointer { p in
            var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(
                mNumberChannels: 2, mDataByteSize: UInt32(count * 2 * 4),
                mData: UnsafeMutableRawPointer(p.baseAddress! + 8)))
            BNRenderAudioBuffers(stereo, &list, UInt32(count))
        }
        #expect(padded.prefix(8).allSatisfy { $0 == 1234 })
        #expect(padded.suffix(8).allSatisfy { $0 == 1234 })
        let left = stride(from: 8, to: 8 + count * 2, by: 2).map { padded[$0] }
        let right = stride(from: 9, to: 9 + count * 2, by: 2).map { padded[$0] }
        #expect(left == reference)
        #expect(right == reference)
    }
}
