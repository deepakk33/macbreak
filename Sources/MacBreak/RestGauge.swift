import Cocoa

/// The rest countdown as a speedometer dial: a thick 270° band, open at the
/// bottom, that drains clockwise while a bead rides its tail like a needle.
///
/// One long Core Animation run per break drives it rather than a redraw per
/// second, so the sweep is continuous instead of ticking.
final class RestGauge: NSView {

    /// Seven-thirty, over the top, round to four-thirty.
    private static let startAngle: CGFloat = .pi * 1.25
    private static let sweep: CGFloat = .pi * 1.5

    private let lineWidth: CGFloat
    private let radius: CGFloat

    private let track = CAShapeLayer()
    private let glow = CALayer()
    private let fill = CAGradientLayer()
    private let band = CAShapeLayer()
    private let needle = CALayer()
    private let bead = CALayer()

    private var total: TimeInterval = 1
    private var endsAt = Date()

    /// How far below the centre the lowest drawn mark sits. The square frame
    /// leaves the dial's open bottom empty, and the layout fills that with text.
    var drawnDepthBelowCenter: CGFloat {
        (radius + lineWidth / 2) * sin(.pi / 4)
    }

    init(side: CGFloat, colors: [NSColor]) {
        lineWidth = (side * 0.07).rounded()
        // Inset a little so the glow is not clipped at the frame edge.
        radius = side / 2 - lineWidth * 1.2
        super.init(frame: NSRect(x: 0, y: 0, width: side, height: side))
        wantsLayer = true
        buildLayers(colors: colors)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private var center: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }

    private func buildLayers(colors: [NSColor]) {
        guard let root = layer else { return }
        let arc = CGMutablePath()
        arc.addArc(center: center, radius: radius,
                   startAngle: Self.startAngle, endAngle: Self.startAngle - Self.sweep,
                   clockwise: true)

        track.path = arc
        track.strokeColor = NSColor(calibratedWhite: 1, alpha: 0.08).cgColor
        track.lineWidth = lineWidth

        band.path = arc
        band.strokeColor = NSColor.black.cgColor
        band.lineWidth = lineWidth

        for shape in [track, band] {
            shape.frame = bounds
            shape.fillColor = nil
            shape.lineCap = .round
        }

        // Left to right across the dial, so the colour shifts as the band drains.
        fill.frame = bounds
        fill.colors = colors.map(\.cgColor)
        fill.startPoint = CGPoint(x: 0, y: 0.5)
        fill.endPoint = CGPoint(x: 1, y: 0.5)
        fill.mask = band

        // The shadow follows the masked band, so the colour glows softly.
        glow.frame = bounds
        glow.shadowColor = colors[colors.count / 2].cgColor
        glow.shadowOpacity = 0.55
        glow.shadowRadius = lineWidth * 0.6
        glow.shadowOffset = .zero
        glow.addSublayer(fill)

        // The bead sits at the band's starting end; turning the full-size
        // needle layer about the centre carries it round the dial.
        let beadSize = lineWidth * 0.55
        bead.bounds = CGRect(x: 0, y: 0, width: beadSize, height: beadSize)
        bead.cornerRadius = beadSize / 2
        bead.backgroundColor = NSColor(calibratedWhite: 1, alpha: 0.95).cgColor
        bead.shadowColor = NSColor.black.cgColor
        bead.shadowOpacity = 0.25
        bead.shadowRadius = 3
        bead.shadowOffset = .zero
        bead.position = point(at: Self.startAngle, radius: radius)
        needle.frame = bounds
        needle.addSublayer(bead)

        for sublayer in [track, glow, needle] {
            root.addSublayer(sublayer)
        }
    }

    private func point(at angle: CGFloat, radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }

    // MARK: - Running

    func run(total: TimeInterval, endsAt: Date) {
        self.total = max(1, total)
        self.endsAt = endsAt
        animate(from: Date())
    }

    /// Core Animation's clock stops while the Mac sleeps and the wall clock
    /// does not. If the two have drifted apart by more than a second, catch up.
    func sync(now: Date) {
        guard let shown = band.presentation()?.strokeStart else { return }
        if abs(Double(shown - progress(at: now))) * total > 1 {
            animate(from: now)
        }
    }

    private func progress(at now: Date) -> CGFloat {
        let left = endsAt.timeIntervalSince(now)
        return CGFloat(min(1, max(0, 1 - left / total)))
    }

    private func animate(from now: Date) {
        let start = progress(at: now)
        let left = max(0, endsAt.timeIntervalSince(now))

        band.removeAllAnimations()
        needle.removeAllAnimations()

        // Park the model layers at the end; the animations run them there.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        band.strokeStart = 1
        needle.transform = CATransform3DMakeRotation(-Self.sweep, 0, 0, 1)
        CATransaction.commit()

        guard left > 0 else { return }

        let drain = CABasicAnimation(keyPath: "strokeStart")
        drain.fromValue = start
        drain.toValue = 1
        drain.duration = left
        drain.timingFunction = CAMediaTimingFunction(name: .linear)
        band.add(drain, forKey: "drain")

        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = -Self.sweep * start
        turn.toValue = -Self.sweep
        turn.duration = left
        turn.timingFunction = CAMediaTimingFunction(name: .linear)
        needle.add(turn, forKey: "turn")
    }

    // MARK: - Retina

    /// Hand-added sublayers do not inherit the window's scale, and blurry
    /// vector strokes on a Retina display look broken.
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        for sublayer in [track, glow, fill, band, needle, bead] {
            sublayer.contentsScale = scale
        }
    }
}
