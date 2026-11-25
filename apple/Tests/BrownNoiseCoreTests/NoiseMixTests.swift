import BrownNoiseDSP
import Foundation
import PlaybackCore
import Testing

struct NoiseMixTests {
    @Test func preservesLegacyBalancesAndNewChoicesOnUpgrade() throws {
        let suite = "NoiseMixTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(NoiseMix.load(from: defaults) == .defaultMix)
        #expect(NoiseMix.defaultMix == NoiseMix(highs: 2, mids: 3, lows: 3))
        defaults.set("brown", forKey: "selectedNoise")
        #expect(NoiseMix.load(from: defaults) == .baseline, "An explicitly saved original Brown must remain unchanged")
        defaults.set("gray", forKey: "selectedNoise")
        #expect(NoiseMix.load(from: defaults) == NoiseMix(highs: 5, mids: 0))
        defaults.set("white", forKey: "selectedNoise")
        #expect(NoiseMix.load(from: defaults) == NoiseMix(highs: 5, mids: 5))
        // Upgrading from the grid must preserve its previously fixed low layer.
        defaults.set(2, forKey: "mixHighs")
        defaults.set(3, forKey: "mixMids")
        #expect(NoiseMix.load(from: defaults) == NoiseMix(highs: 3, mids: 4, lows: 5))
        for lows in NoiseMix.levels {
          for highs in NoiseMix.levels {
            for mids in NoiseMix.levels {
                let mix = NoiseMix(highs: highs, mids: mids, lows: lows)
                mix.save(to: defaults)
                #expect(NoiseMix.load(from: defaults) == mix)
            }
          }
        }
        let off = NoiseMix(highs: 0, mids: 0, lows: 0)
        off.save(to: defaults)
        #expect(NoiseMix.load(from: defaults) == off, "A saved low zero must not migrate back to full bass")
        #expect(off.isSilent)
        #expect(!NoiseMix.baseline.isSilent)
        NoiseMix.baseline.save(to: defaults)
        #expect(NoiseMix.load(from: defaults) == .baseline, "Saved zero must not fall back to an old preset")
    }

    @Test func invalidStoredCoordinatesCannotRequestExcessiveGain() throws {
        let suite = "NoiseMixTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(300, forKey: "mixHighs")
        defaults.set(-5, forKey: "mixMids")
        defaults.set(-300, forKey: "mixLows")
        #expect(NoiseMix.load(from: defaults) == NoiseMix(highs: 5, mids: 0, lows: 0))
        defaults.set(300, forKey: "mixLows")
        #expect(NoiseMix.load(from: defaults).lows == 5)
    }

    @Test func everyOldCoordinateMigratesExactlyOnceAndStaysAvailableForRollback() throws {
        let suite = "NoiseMixMigration." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        func migrated(_ old: Int) -> Int { old == 0 ? 0 : old + 1 }
        for low in 0...4 { for mid in 0...4 { for high in 0...4 {
            defaults.removeObject(forKey: NoiseMix.preferenceKey)
            defaults.set(low, forKey: "mixLows")
            defaults.set(mid, forKey: "mixMids")
            defaults.set(high, forKey: "mixHighs")
            let expected = NoiseMix(highs: migrated(high), mids: migrated(mid), lows: migrated(low))
            #expect(NoiseMix.load(from: defaults) == expected)
            #expect(NoiseMix.load(from: defaults) == expected)
            expected.save(to: defaults)
            #expect(NoiseMix.load(from: defaults) == expected)
            #expect(defaults.integer(forKey: "mixLows") == low)
            #expect(defaults.integer(forKey: "mixMids") == mid)
            #expect(defaults.integer(forKey: "mixHighs") == high)
        } } }
        defaults.set(["low": 1], forKey: NoiseMix.preferenceKey)
        #expect(NoiseMix.load(from: defaults) == NoiseMix(highs: 5, mids: 5, lows: 5),
                "Incomplete new data falls back to the intact old balance")
        defaults.set(["low": Int.max, "mid": Int.min, "high": 1], forKey: NoiseMix.preferenceKey)
        #expect(NoiseMix.load(from: defaults) == NoiseMix(highs: 1, mids: 0, lows: 5))
    }

    @Test func sixLevelsMatchProductionDSPAndAddATraceOfPower() {
        #expect(Int(BNMixLevelCount) == NoiseMix.levels.count)
        let expectedDB: [Double?] = [nil, -30, -18, -12, -6, 0]
        for level in NoiseMix.levels {
            #expect(NoiseMix.relativeDecibels(at: level) == expectedDB[level])
            let amplitude = BNMixAmplitudeForLevel(Int32(level))
            #expect(abs(amplitude * amplitude - NoiseMix.relativePower(at: level)) < 1e-15)
        }
        #expect(abs(NoiseMix.relativePower(at: 1) - 0.001) < 1e-15)
        #expect(abs(NoiseMix.relativePower(at: 2) / NoiseMix.relativePower(at: 1) - 15.8489319246) < 1e-9)
        #expect(BNMixAmplitudeForLevel(Int32.min) == 0)
        #expect(BNMixAmplitudeForLevel(Int32.max) == 1)
        #expect(NoiseMix.relativePower(at: Int.min) == 0)
        #expect(NoiseMix.relativePower(at: Int.max) == 1)
    }
}
