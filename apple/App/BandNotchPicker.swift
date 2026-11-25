import SwiftUI
import UIKit
import PlaybackCore

/// Coordinates are continuous for touch handling; only six integer levels
/// ever cross the boundary into the existing audio service.
enum BandNotches {
    static func level(at position: Float) -> Int {
        guard position.isFinite else { return 0 }
        return Int((min(1, max(0, position)) * Float(NoiseMix.maximumLevel)).rounded())
    }
    static func position(for level: Int) -> Float { Float(NoiseMix.clamp(level)) / Float(NoiseMix.maximumLevel) }
    static func description(for level: Int) -> String { NoiseMix.levelDescription(level) }
}

struct BandNotchPicker: View {
    let title: String
    let id: String
    let level: Int
    let showsColor: Bool
    let animate: Bool
    let components: SIMD3<Double>
    let select: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppTypography.band)
                .foregroundStyle(Color(white: 0.75))
                .accessibilityAddTraits(.isHeader)
            NotchedSlider(level: level, title: title, id: id, components: components,
                          showsColor: showsColor, animate: animate, select: select)
                .frame(height: 56)
                .saturation(showsColor ? 1 : 0)
                .animation(animate ? .easeInOut(duration: 1.4) : nil, value: showsColor)
        }
    }
}

private struct NotchedSlider: UIViewRepresentable {
    let level: Int
    let title: String
    let id: String
    let components: SIMD3<Double>
    let showsColor: Bool
    let animate: Bool
    let select: (Int) -> Void

    func makeUIView(context: Context) -> NotchedLevelSlider {
        let slider = NotchedLevelSlider()
        slider.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return slider
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NotchedLevelSlider, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return CGSize(width: width, height: 56)
    }

    func updateUIView(_ slider: NotchedLevelSlider, context: Context) {
        context.coordinator.parent = self
        slider.accessibilityIdentifier = "band-\(id)-slider"
        slider.accessibilityLabel = "\(title) frequency intensity"
        slider.accessibilityValue = BandNotches.description(for: level)
        slider.accessibilityHint = "Six stops. Swipe up or down to change intensity."
        slider.animatesChanges = animate
        let position = BandNotches.position(for: level)
        if !slider.isTracking && slider.value != position { slider.setValue(position, animated: false) }
        slider.updateColors(components, sounding: showsColor, animated: animate)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    @MainActor final class Coordinator: NSObject {
        var parent: NotchedSlider
        init(_ parent: NotchedSlider) { self.parent = parent }
        @objc func changed(_ slider: NotchedLevelSlider) {
            let level = BandNotches.level(at: slider.value)
            slider.accessibilityValue = BandNotches.description(for: level)
            if level != parent.level { parent.select(level) }
        }
    }
}

/// UIKit retains touch tracking and accessibility. The custom window leaves
/// the selected circle exposed, unlike an opaque thumb placed over the mark.
final class NotchedLevelSlider: UISlider {
    var animatesChanges = true
    private let rail = CAGradientLayer()
    private let notches = CAShapeLayer()
    private let notchOverlay = UIView()
    private let selectionWindow = ScaleSelectionWindow()
    private var lastComponents: SIMD3<Double>?
    private var lastSounding: Bool?

    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumValue = 0; maximumValue = 1
        backgroundColor = .clear
        semanticContentAttribute = .forceLeftToRight
        // Use public appearance hooks; no native view hierarchy is hidden or
        // inspected. Custom images also avoid native stretching/momentum art.
        let blankThumb = UIGraphicsImageRenderer(size: ScaleSelectionWindow.size).image { _ in }
        let blankTrack = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        for state: UIControl.State in [.normal, .highlighted, .disabled, .selected, .focused] {
            setThumbImage(blankThumb, for: state)
            setMinimumTrackImage(blankTrack, for: state)
            setMaximumTrackImage(blankTrack, for: state)
        }
        rail.startPoint = CGPoint(x: 0, y: 0.5)
        rail.endPoint = CGPoint(x: 1, y: 0.5)
        rail.cornerRadius = 5
        rail.borderWidth = 0.5
        rail.borderColor = UIColor(white: 0.5, alpha: 0.25).cgColor
        layer.insertSublayer(rail, at: 0)
        notches.fillColor = UIColor(white: 0.94, alpha: 1).cgColor
        notches.shadowColor = UIColor.black.cgColor
        notches.shadowOpacity = 0.45
        notches.shadowRadius = 1.5
        notches.shadowOffset = .zero
        addSubview(selectionWindow)
        notchOverlay.isUserInteractionEnabled = false
        notchOverlay.isAccessibilityElement = false
        notchOverlay.backgroundColor = .clear
        notchOverlay.layer.addSublayer(notches)
        addSubview(notchOverlay)
        addTarget(self, action: #selector(trackedValueChanged), for: .valueChanged)
        addTarget(self, action: #selector(finishTracking), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: super.intrinsicContentSize.width, height: 56)
    }

    private var railEnds: (CGFloat, CGFloat) {
        let rect = trackRect(forBounds: bounds)
        return (rect.minX, rect.maxX)
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        // Two points outside the window remain at both extremes, so neither
        // the outline nor its glass highlights are cut off at Off/full.
        CGRect(x: bounds.minX + 28, y: bounds.midY - 1,
               width: max(1, bounds.width - 56), height: 10)
    }

    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let x = rect.minX + rect.width * CGFloat(min(1, max(0, value)))
        return CGRect(x: x - ScaleSelectionWindow.size.width / 2, y: bounds.midY - 22,
                      width: ScaleSelectionWindow.size.width, height: ScaleSelectionWindow.size.height)
    }

    override func setValue(_ value: Float, animated: Bool) {
        super.setValue(value, animated: false)
        if animated && animatesChanges && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.24, delay: 0,
                           options: [.beginFromCurrentState, .curveEaseInOut, .allowUserInteraction]) {
                self.positionWindow()
            }
        } else { positionWindow() }
    }

    private func positionWindow() {
        let target = thumbRect(forBounds: bounds, trackRect: trackRect(forBounds: bounds), value: value)
        if selectionWindow.frame != target { selectionWindow.frame = target }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let (start, end) = railEnds
        CATransaction.begin(); CATransaction.setDisableActions(true)
        rail.frame = trackRect(forBounds: bounds)
        notchOverlay.frame = bounds
        notches.frame = bounds
        let path = UIBezierPath()
        for index in NoiseMix.levels {
            let x = start + (end - start) * CGFloat(index) / CGFloat(NoiseMix.maximumLevel)
            path.append(UIBezierPath(ovalIn: CGRect(x: x - 4.5, y: rail.frame.midY - 4.5, width: 9, height: 9)))
        }
        notches.path = path.cgPath
        notches.shadowPath = path.cgPath
        CATransaction.commit()
        positionWindow()
        bringSubviewToFront(selectionWindow)
        // Place the fixed scale marks above the glass sampling surface. They
        // stay sharp inside the window and cannot produce refracted duplicates.
        bringSubviewToFront(notchOverlay)
    }

    func updateColors(_ components: SIMD3<Double>, sounding: Bool, animated: Bool) {
        guard lastComponents != components || lastSounding != sounding else { return }
        let hadColor = lastComponents != nil
        lastComponents = components; lastSounding = sounding
        let base = SIMD3<Double>(repeating: LinearLight.decode(0.025))
        let end = sounding ? LinearLight.decode(components) : SIMD3(repeating: LinearLight.decode(0.30))
        // Dense, explicitly encoded samples preserve linear-light intensity
        // across the rail without relying on Core Animation's working space.
        let colors: [CGColor] = (0...64).map { index in
            let t = Double(index) / 64
            let linear = base * (1 - t) + end * t
            return UIColor(red: LinearLight.encode(linear.x), green: LinearLight.encode(linear.y),
                           blue: LinearLight.encode(linear.z), alpha: 1).cgColor
        }
        let previous = rail.presentation()?.colors ?? rail.colors
        CATransaction.begin(); CATransaction.setDisableActions(true)
        rail.colors = colors
        CATransaction.commit()
        rail.removeAnimation(forKey: "palette")
        if animated && hadColor {
            let fade = CABasicAnimation(keyPath: "colors")
            fade.fromValue = previous; fade.toValue = colors; fade.duration = 1.4
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            rail.add(fade, forKey: "palette")
        }
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let (start, end) = railEnds
        let position = Float((gesture.location(in: self).x - start) / max(1, end - start))
        choose(BandNotches.level(at: position))
    }
    @objc private func finishTracking() { choose(BandNotches.level(at: value)) }
    @objc private func trackedValueChanged() { positionWindow() }

    private func choose(_ level: Int) {
        let target = BandNotches.position(for: level)
        if animatesChanges && !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.24, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut, .allowUserInteraction]) {
                self.setValue(target, animated: false)
                self.layoutIfNeeded()
            }
        } else { setValue(target, animated: false) }
        accessibilityValue = BandNotches.description(for: level)
        sendActions(for: .valueChanged)
    }

    override func accessibilityIncrement() { choose(min(NoiseMix.maximumLevel, BandNotches.level(at: value) + 1)) }
    override func accessibilityDecrement() { choose(max(0, BandNotches.level(at: value) - 1)) }
}

/// A balance-scale rider: clear glass, a defined rim, and an inward pointer.
/// The stationary scale circles are drawn above this material, staying sharp.
private final class ScaleSelectionWindow: UIView {
    static let size = CGSize(width: 52, height: 44)
    private let glass: UIVisualEffectView
    private let rim = CAShapeLayer()
    private let pointer = CAShapeLayer()
    private var lastSize = CGSize.zero

    override init(frame: CGRect) {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .clear)
            effect.isInteractive = false
            glass = UIVisualEffectView(effect: effect)
        } else {
            glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        }
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        addSubview(glass)
        if #available(iOS 26.0, *) { glass.cornerConfiguration = .uniformCorners(radius: 13) }
        else { glass.layer.cornerRadius = 13; glass.clipsToBounds = true }
        rim.fillColor = UIColor.clear.cgColor
        rim.strokeColor = UIColor(white: 0.92, alpha: 0.70).cgColor
        rim.lineWidth = 1.2
        layer.addSublayer(rim)
        pointer.fillColor = UIColor(white: 0.94, alpha: 1).cgColor
        pointer.strokeColor = pointer.fillColor
        pointer.lineWidth = 1
        pointer.lineJoin = .round
        layer.addSublayer(pointer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastSize else { return }
        lastSize = bounds.size
        CATransaction.begin(); CATransaction.setDisableActions(true)
        glass.frame = bounds
        rim.frame = bounds
        rim.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.8, dy: 0.8), cornerRadius: 12.2).cgPath
        pointer.frame = bounds
        let arrow = UIBezierPath()
        arrow.move(to: CGPoint(x: bounds.midX - 4.5, y: 4))
        arrow.addLine(to: CGPoint(x: bounds.midX + 4.5, y: 4))
        arrow.addLine(to: CGPoint(x: bounds.midX, y: 15))
        arrow.close()
        pointer.path = arrow.cgPath
        CATransaction.commit()
    }
}
