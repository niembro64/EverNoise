import Foundation
import PlaybackCore
import Testing

struct NoiseMixTests {
    @Test func preservesLegacyBalancesAndNewChoicesOnUpgrade() throws {
        let suite = "NoiseMixTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(NoiseMix.load(from: defaults) == .defaultMix)
        #expect(NoiseMix.defaultMix == NoiseMix(highs: 1, mids: 2, lows: 2))
        defaults.set("brown", forKey: "selectedNoise")
        #expect(NoiseMix.load(from: defaults) == .baseline, "An explicitly saved original Brown must remain unchanged")
        defaults.set("gray", forKey: "selectedNoise")
        #expect(NoiseMix.load(from: defaults) == NoiseMix(highs: 4, mids: 0))
        defaults.set("white", forKey: "selectedNoise")
        #expect(NoiseMix.load(from: defaults) == NoiseMix(highs: 4, mids: 4))
        // Upgrading from the grid must preserve its previously fixed low layer.
        defaults.set(2, forKey: "mixHighs")
        defaults.set(3, forKey: "mixMids")
        #expect(NoiseMix.load(from: defaults) == NoiseMix(highs: 2, mids: 3, lows: 4))
        for lows in 0...4 {
          for highs in 0...4 {
            for mids in 0...4 {
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
        #expect(NoiseMix.load(from: defaults) == NoiseMix(highs: 4, mids: 0, lows: 0))
        defaults.set(300, forKey: "mixLows")
        #expect(NoiseMix.load(from: defaults).lows == 4)
    }
}
