import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore
#endif

/// Static, non-interactive hex grid (vector line art).
struct HexGridView: View {

    var n: Int = 8
    var lineColor: Color = Color(red: 0.45, green: 0.45, blue: 0.45)
    var relativeLineWidth: Double = 0.018

    var body: some View {
        Canvas { context, size in
            let w = Double(size.width)
            let h = Double(size.height)
            var path = Path()
            for hex in HexGrid.polygons(n: n, inWidth: w, height: h) {
                for (i, p) in hex.enumerated() {
                    let pt = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                path.closeSubpath()
            }
            let lw = max(
                0.5, CGFloat(HexGrid.radiusFitting(n: n, width: w, height: h)) * relativeLineWidth)
            context.stroke(
                path, with: .color(lineColor),
                style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        }
        .background(Color.white)
    }
}
