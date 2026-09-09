import CoreGraphics

/// Top-down geometry: an attached top edge, concave shoulders, rounded lower body.
/// Independently implemented from Loch's written design language; no copied source.
public enum NotchGeometry {
    public static func height(safeTop: Double, scale: Double) -> Double {
        (safeTop > 0 ? safeTop : 32) + 1 / max(1, scale)
    }
    public static func outline(width w: Double, height h: Double) -> CGPath {
        let p = CGMutablePath()
        let tuck = min(10, h * 0.30), drop = min(10, h * 0.28), radius = min(12, h * 0.36)
        p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: w, y: 0))
        p.addCurve(to: CGPoint(x: w-tuck, y: drop), control1: CGPoint(x: w-tuck, y: 0), control2: CGPoint(x: w-tuck, y: drop*0.35))
        p.addLine(to: CGPoint(x: w-tuck, y: h-radius))
        p.addQuadCurve(to: CGPoint(x: w-tuck-radius, y: h), control: CGPoint(x: w-tuck, y: h))
        p.addLine(to: CGPoint(x: tuck+radius, y: h))
        p.addQuadCurve(to: CGPoint(x: tuck, y: h-radius), control: CGPoint(x: tuck, y: h))
        p.addLine(to: CGPoint(x: tuck, y: drop))
        p.addCurve(to: .zero, control1: CGPoint(x: tuck, y: drop*0.35), control2: CGPoint(x: tuck, y: 0))
        p.closeSubpath(); return p
    }
}
