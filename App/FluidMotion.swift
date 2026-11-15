import Foundation

/// Three cascaded exponential stages. Retargeting preserves the displayed value,
/// velocity AND acceleration, including rapid repeated play/pause/color changes.
/// Exact integration makes the trajectory independent of display frame rate.
struct FluidSmoother {
    private(set) var first: Double
    private(set) var second: Double
    private(set) var value: Double
    private(set) var target: Double
    static let rate = 5.0

    init(_ value: Double) {
        first = value; second = value; self.value = value; target = value
    }

    var velocity: Double { Self.rate * (second - value) }
    var acceleration: Double { Self.rate * Self.rate * (first - 2 * second + value) }

    mutating func retarget(_ target: Double) { self.target = target }

    @discardableResult
    mutating func advance(by elapsed: Double) -> Double {
        let time = max(0, elapsed)
        let q = Self.rate * time
        let decay = exp(-q)
        let a = first - target, b = second - target, c = value - target
        let integral = target * time + (c * (1 - decay)
            + b * (1 - decay * (1 + q))
            + a * (1 - decay * (1 + q + q * q / 2))) / Self.rate
        first = target + a * decay
        second = target + (b + q * a) * decay
        value = target + (c + q * b + q * q * a / 2) * decay
        return integral
    }

    mutating func settle() { self = Self(target) }
}

struct FluidMotion {
    struct Frame {
        let phase: Double
        let activity: Double
        let color: SIMD3<Double>
        let bandPower: SIMD3<Double>
        let ambience: Double
    }

    private var timestamp: Double
    private var visible = false
    private var flowSeconds = 0.0
    private var speed = FluidSmoother(0)
    private var activity = FluidSmoother(0)
    // Color smoothers carry linear light, just like the shader inputs.
    private var red = FluidSmoother(LinearLight.decode(0.7))
    private var green = FluidSmoother(LinearLight.decode(0.35))
    private var blue = FluidSmoother(LinearLight.decode(0.5))
    private var lowPower = FluidSmoother(0)
    private var midPower = FluidSmoother(0)
    private var highPower = FluidSmoother(0)
    private var ambience = FluidSmoother(0)

    init(now: Double) { timestamp = now }

    mutating func update(color: SIMD3<Double>, sounding: Bool, visible: Bool,
                         reduceMotion: Bool, bandPower: SIMD3<Double> = .zero,
                         animationLevel: AnimationLevel = .medium, at now: Double) {
        advance(to: now)
        self.visible = visible
        if !visible { speed = FluidSmoother(0) }
        speed.retarget(sounding && visible && !reduceMotion && animationLevel.animatesInfinity ? 1 : 0)
        activity.retarget(sounding ? 1 : 0)
        red.retarget(color.x); green.retarget(color.y); blue.retarget(color.z)
        lowPower.retarget(bandPower.x); midPower.retarget(bandPower.y); highPower.retarget(bandPower.z)
        ambience.retarget(animationLevel.showsRibbons && !reduceMotion ? 1 : 0)
        // A disabled preference is a genuinely static renderer, even while
        // changing colors or playing/pausing. No four-second display timer.
        if !animationLevel.animatesInfinity { settle(at: now) }
    }

    func sample(at now: Double) -> Frame {
        var copy = self
        copy.advance(to: now)
        // Every shader time coefficient is an integer harmonic of this phase.
        // The 240-second wrap is visually seamless, with no Float clock drift.
        return Frame(phase: copy.flowSeconds * 2 * .pi / 240,
                     activity: copy.activity.value,
                     color: SIMD3(copy.red.value, copy.green.value, copy.blue.value),
                     bandPower: SIMD3(copy.lowPower.value, copy.midPower.value, copy.highPower.value),
                     ambience: copy.ambience.value)
    }

    mutating func settle(at now: Double) {
        advance(to: now)
        speed.settle(); activity.settle()
        red.settle(); green.settle(); blue.settle()
        lowPower.settle(); midPower.settle(); highPower.settle(); ambience.settle()
    }

    private mutating func advance(to now: Double) {
        let elapsed = visible ? max(0, now - timestamp) : 0
        flowSeconds = (flowSeconds + speed.advance(by: elapsed)).truncatingRemainder(dividingBy: 240)
        activity.advance(by: elapsed)
        red.advance(by: elapsed); green.advance(by: elapsed); blue.advance(by: elapsed)
        lowPower.advance(by: elapsed); midPower.advance(by: elapsed); highPower.advance(by: elapsed)
        ambience.advance(by: elapsed)
        timestamp = now
    }
}
