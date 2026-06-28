import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore  // macOS executable: core is a package dependency
#endif

/// Renders an `n` × `n` static grid of flat-top hexagons as vector line art.
///
/// All geometry is delegated to `HexGrid` (Foundation-only, unit-tested). The
/// hex radius is derived from the view's current `CGSize` inside `Canvas`, so
/// nothing is baked at a fixed pixel size and the drawing stays sharp at any
/// resolution or scale factor.
struct HexGridView: View {

    var n: Int = 8
    var lineColor: Color = Color(red: 0.45, green: 0.45, blue: 0.45)
    var relativeLineWidth: Double = 0.018

    var body: some View {
        Canvas { context, size in
            let width = Double(size.width)
            let height = Double(size.height)
            let polygons = HexGrid.polygons(n: n, inWidth: width, height: height)

            var path = Path()
            for hex in polygons {
                for (i, p) in hex.enumerated() {
                    // Core geometry is in Double; convert to CGFloat at the
                    // SwiftUI/CoreGraphics boundary (no implicit conversion).
                    let point = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
            }

            // Radius is proportional to size, so the stroke scales with it.
            let radius = CGFloat(HexGrid.radiusFitting(n: n, width: width, height: height))
            let lineWidth = max(0.5, radius * CGFloat(relativeLineWidth))
            context.stroke(
                path,
                with: .color(lineColor),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .background(Color.white)
    }
}
