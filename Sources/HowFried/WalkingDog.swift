import SwiftUI

/// Compact puppy silhouette; short paddling paws stay tucked under its belly.
struct WalkingDog: View {
    var phase: Double
    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width/220, y: size.height/170)
            let gold = Color(red: 0.89, green: 0.63, blue: 0.29)
            let light = Color(red: 0.98, green: 0.78, blue: 0.45)
            let cream = Color(red: 1, green: 0.87, blue: 0.62)
            let shade = Color(red: 0.69, green: 0.43, blue: 0.21)
            func ellipse(_ rect: CGRect, _ color: Color) { context.fill(Path(ellipseIn: rect), with: .color(color)) }
            func leg(x: Double, offset: Double, color: Color) {
                let swing = sin(phase+offset), lift = max(0, cos(phase+offset))*4
                let footX = x+swing*7, footY = 144-lift
                var path = Path(); path.move(to: CGPoint(x: x, y: 123))
                path.addQuadCurve(to: CGPoint(x: footX, y: footY), control: CGPoint(x: x+swing*3, y: 137))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 17, lineCap: .round))
                ellipse(CGRect(x: footX-8, y: footY-5, width: 23, height: 13), color)
            }
            var tail = Path(); tail.move(to: CGPoint(x: 68, y: 105))
            tail.addQuadCurve(to: CGPoint(x: 43, y: 77+sin(phase*0.7)*5), control: CGPoint(x: 40, y: 107))
            context.stroke(tail, with: .color(gold), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            leg(x: 88, offset: .pi, color: shade); leg(x: 135, offset: 0, color: shade)
            ellipse(CGRect(x: 60, y: 77, width: 100, height: 64), gold)
            ellipse(CGRect(x: 89, y: 97, width: 65, height: 43), light)
            leg(x: 76, offset: 0, color: gold); leg(x: 125, offset: .pi, color: light)
            // Head overlaps the shoulders directly: no long upright neck.
            ellipse(CGRect(x: 113, y: 44, width: 70, height: 67), light)
            ellipse(CGRect(x: 145, y: 77, width: 48, height: 30), cream)
            ellipse(CGRect(x: 176, y: 78, width: 15, height: 11), Palette.face)
            ellipse(CGRect(x: 160, y: 65, width: 8, height: 11), Palette.face)
            ellipse(CGRect(x: 162, y: 66, width: 2.5, height: 3), .white)
            ellipse(CGRect(x: 112, y: 57+sin(phase)*1.3, width: 27, height: 48), shade)
            ellipse(CGRect(x: 151, y: 85, width: 10, height: 6), Color(red: 0.95, green: 0.64, blue: 0.42))
            var scarf = Path(); scarf.move(to: CGPoint(x: 129, y: 106)); scarf.addQuadCurve(to: CGPoint(x: 170, y: 104), control: CGPoint(x: 150, y: 112)); scarf.addLine(to: CGPoint(x: 151, y: 125)); scarf.closeSubpath()
            context.fill(scarf, with: .color(Palette.bandana))
            var smile = Path(); smile.move(to: CGPoint(x: 163, y: 96)); smile.addQuadCurve(to: CGPoint(x: 182, y: 94), control: CGPoint(x: 174, y: 103))
            context.stroke(smile, with: .color(Palette.face), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }.accessibilityLabel("A round golden puppy trotting on short paws")
    }
}
