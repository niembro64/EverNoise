import XCTest
import PlaybackCore
@testable import JustBrownNoise

final class FluidMotionTests: XCTestCase {
    func testPaletteUsesDecibelPowerAndSharedMutedColors() {
        XCTAssertEqual(RibbonPalette.power(at: 0), 0)
        XCTAssertEqual(RibbonPalette.power(at: 4), 1)
        for level in 1..<4 {
            XCTAssertEqual(10 * log10(RibbonPalette.power(at: level + 1) /
                                     RibbonPalette.power(at: level)), 6, accuracy: 1e-12)
        }
        let p = RibbonPalette(mix: NoiseMix(highs: 3, mids: 2, lows: 4))
        XCTAssertEqual(p.bandPower.x, 1)
        XCTAssertEqual(p.bandPower.y, pow(10, -1.2), accuracy: 1e-12)
        XCTAssertEqual(p.bandPower.z, pow(10, -0.6), accuracy: 1e-12)
        XCTAssertEqual(RibbonPalette(mix: NoiseMix(highs: 0, mids: 0, lows: 4)).mixedColor, NoisePalette.linearHues[0])
        XCTAssertEqual(RibbonPalette(mix: NoiseMix(highs: 0, mids: 0, lows: 0)).mixedColor, .zero)
    }

    func testLowFreezesInfinityHidesRibbonsAndUpdatesStaticColor() {
        let color = SIMD3(0.7, 0.35, 0.525)
        var motion = FluidMotion(now: 0)
        motion.update(color: color, sounding: true, visible: true, reduceMotion: false, at: 0)
        motion.update(color: color, sounding: true, visible: true, reduceMotion: false,
                      bandPower: SIMD3(1, 0.1, 0.2), animationLevel: .low, at: 10)
        let disabled = motion.sample(at: 10)
        XCTAssertEqual(disabled.ambience, 0)
        XCTAssertEqual(motion.sample(at: 43_210).phase, disabled.phase)
        motion.update(color: SIMD3(0.2, 0.7, 0.4), sounding: true, visible: true, reduceMotion: false,
                      bandPower: SIMD3(0.1, 1, 0.2), animationLevel: .low, at: 43_210)
        XCTAssertEqual(motion.sample(at: 43_210).color, SIMD3(0.2, 0.7, 0.4))
        motion.update(color: color, sounding: true, visible: true, reduceMotion: false,
                      animationLevel: .medium, at: 43_210)
        XCTAssertEqual(motion.sample(at: 43_210).phase, disabled.phase)
        XCTAssertLessThan(motion.sample(at: 43_210.01).phase - disabled.phase, 0.00000001)
    }

    func testMediumAnimatesOnlyInfinityAndHighAddsRibbonsWithoutRestartingFlow() {
        let color = SIMD3(0.7, 0.35, 0.525)
        var motion = FluidMotion(now: 0)
        motion.update(color: color, sounding: true, visible: true, reduceMotion: false, at: 0)
        XCTAssertEqual(motion.sample(at: 10).ambience, 0, "Med is the default and has no ribbons")
        XCTAssertGreaterThan(motion.sample(at: 11).phase, motion.sample(at: 10).phase)
        let medium = motion.sample(at: 12)
        motion.update(color: color, sounding: true, visible: true, reduceMotion: false,
                      animationLevel: .high, at: 12)
        XCTAssertEqual(motion.sample(at: 12).phase, medium.phase)
        XCTAssertEqual(motion.sample(at: 12).ambience, 0, "Ribbons fade in without appearing abruptly")
        motion.settle(at: 16)
        XCTAssertEqual(motion.sample(at: 16).ambience, 1)
        let high = motion.sample(at: 17)
        motion.update(color: color, sounding: true, visible: true, reduceMotion: false,
                      animationLevel: .medium, at: 17)
        XCTAssertEqual(motion.sample(at: 17).phase, high.phase)
        XCTAssertEqual(motion.sample(at: 17).ambience, 1, "Ribbons fade out smoothly")
        motion.settle(at: 21)
        XCTAssertEqual(motion.sample(at: 21).ambience, 0)
        XCTAssertGreaterThan(motion.sample(at: 22).phase, motion.sample(at: 21).phase)
    }

    func testRetargetPreservesValueVelocityAndAcceleration() {
        var smoother = FluidSmoother(0)
        smoother.retarget(1)
        for index in 0..<120 {
            smoother.advance(by: 0.013 + Double(index % 7) * 0.009)
            let before = (smoother.value, smoother.velocity, smoother.acceleration)
            smoother.retarget(index.isMultiple(of: 2) ? 0 : 1)
            XCTAssertEqual(smoother.value, before.0)
            XCTAssertEqual(smoother.velocity, before.1)
            XCTAssertEqual(smoother.acceleration, before.2)
            XCTAssertTrue((0...1).contains(smoother.value))
        }
    }

    func testClockDoesNotDependOnFrameRate() {
        var single = FluidSmoother(0)
        single.retarget(1)
        var frames = single
        let integral = single.advance(by: 17)
        var rendered = 0.0
        for _ in 0..<1_020 { rendered += frames.advance(by: 1.0 / 60) }
        XCTAssertEqual(integral, rendered, accuracy: 1e-11)
        XCTAssertEqual(single.value, frames.value, accuracy: 1e-13)
    }

    func testSettlingCannotProduceAVisibleJump() {
        var smoother = FluidSmoother(1)
        smoother.retarget(0)
        smoother.advance(by: 4)
        XCTAssertLessThan(smoother.value, 0.000001)
        XCTAssertLessThan(abs(smoother.velocity), 0.000003)
        // At 30 points/second full speed, all remaining travel is subpixel.
        XCTAssertLessThan(smoother.advance(by: 10) * 30, 0.00001)
    }

    func testBackgroundPreservesPositionAndRestartsGradually() {
        let color = SIMD3(0.7, 0.35, 0.525)
        var motion = FluidMotion(now: 0)
        motion.update(color: color, sounding: true, visible: true, reduceMotion: false, at: 0)
        let before = motion.sample(at: 20)
        motion.update(color: color, sounding: true, visible: false, reduceMotion: false, at: 20)
        XCTAssertEqual(motion.sample(at: 43_220).phase, before.phase)
        motion.update(color: color, sounding: true, visible: true, reduceMotion: false, at: 43_220)
        XCTAssertEqual(motion.sample(at: 43_220).phase, before.phase)
        XCTAssertLessThan(motion.sample(at: 43_220.01).phase - before.phase, 0.00000001)
    }

    func testPausedAndReducedMotionSettleToStillFrames() {
        let color = SIMD3(0.7, 0.0, 0.525)
        for reduced in [false, true] {
            var motion = FluidMotion(now: 0)
            motion.update(color: color, sounding: true, visible: true, reduceMotion: false, at: 0)
            motion.update(color: color, sounding: reduced, visible: true, reduceMotion: reduced,
                          animationLevel: .high, at: 10)
            motion.settle(at: 14)
            XCTAssertEqual(motion.sample(at: 14).phase, motion.sample(at: 1_000).phase)
            XCTAssertEqual(motion.sample(at: 14).activity, reduced ? 1 : 0)
            if reduced { XCTAssertEqual(motion.sample(at: 14).ambience, 0) }
        }
    }
}
