import Foundation

// MARK: - HexPoint

/// A point in planar coordinates. Kept as a plain value (not CGPoint) so the
/// geometry has no UIKit / SwiftUI / CoreGraphics dependency and stays
/// trivially unit-testable and portable.
public struct HexPoint: Equatable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

// MARK: - HexGrid

/// A hexagonal cluster of **pointy-top** hexagons: a "hexagon of hexagons" with
/// `n` hexagons along each side (3n² − 3n + 1 cells in total).
///
/// Cells are addressed with axial coordinates (q, r); a cell belongs to the
/// cluster iff its cube radius max(|q|, |r|, |q+r|) ≤ n − 1. Pointy-top layout
/// puts every cell with the same `r` on the same horizontal row, so the cluster
/// reads naturally left-to-right, top-to-bottom — the traversal order returned
/// by `cells()`. Every coordinate is a linear function of `radius` (the
/// center-to-vertex distance), so the whole cluster scales uniformly and stays
/// sharp at any resolution.
public struct HexGrid {

    public static let sqrt3: Double = 3.0.squareRoot()

    /// Number of hexagons per side of the cluster.
    public let n: Int

    /// Center-to-vertex distance of each hexagon.
    public let radius: Double

    public init(n: Int, radius: Double) {
        precondition(n >= 0, "n must be non-negative")
        precondition(radius >= 0, "radius must be non-negative")
        self.n = n
        self.radius = radius
    }

    /// Number of cells in the cluster: 3n² − 3n + 1.
    public var cellCount: Int { 3 * n * n - 3 * n + 1 }

    /// Total bounding size of the cluster at the current radius.
    ///   width  = s · √3 · (2n − 1)
    ///   height = s · (3n − 1)
    public var boundsWidth: Double  { Self.sqrt3 * radius * Double(2 * n - 1) }
    public var boundsHeight: Double { radius * Double(3 * n - 1) }

    /// Largest radius that fits the cluster inside `width × height` with
    /// `margin` on each side.
    public static func radiusFitting(
        n: Int, width: Double, height: Double, margin: Double = 8
    ) -> Double {
        guard n > 0 else { return 0 }
        let availableW = max(0, width  - 2 * margin)
        let availableH = max(0, height - 2 * margin)
        let byWidth  = availableW / (sqrt3 * Double(2 * n - 1))
        let byHeight = availableH / Double(3 * n - 1)
        return Swift.min(byWidth, byHeight)
    }

    /// Cells in reading order: top-to-bottom by row (`r` ascending), and
    /// left-to-right within each row (`q` ascending, since x grows with q for a
    /// fixed r). This linear order is the auto-advance traversal.
    public func cells() -> [(q: Int, r: Int)] {
        let k = n - 1
        guard k >= 0 else { return [] }
        var out: [(q: Int, r: Int)] = []
        out.reserveCapacity(cellCount)
        for r in -k...k {
            // Cube constraint max(|q|,|r|,|q+r|) ≤ k  ⇔  q ∈ [max(-k,-k-r), min(k,k-r)]
            let qMin = Swift.max(-k, -k - r)
            let qMax = Swift.min(k,  k - r)
            for q in qMin...qMax { out.append((q, r)) }
        }
        return out
    }

    /// Pixel center of cell (q, r) for pointy-top axial layout. The axial origin
    /// (0, 0) maps to `(originX, originY)`, so the cluster is centered in its
    /// frame by passing the frame's midpoint.
    public func center(q: Int, r: Int, originX: Double = 0, originY: Double = 0) -> HexPoint {
        let cx = originX + radius * Self.sqrt3 * (Double(q) + Double(r) / 2)
        let cy = originY + radius * 1.5 * Double(r)
        return HexPoint(cx, cy)
    }

    /// The six vertices of a pointy-top hexagon (angles 30°,90°,…,330°) centered
    /// at `c`, each at distance `radius` from the center.
    public func vertices(centeredAt c: HexPoint) -> [HexPoint] {
        (0..<6).map { k in
            let angle = Double.pi / 6 + Double(k) * Double.pi / 3
            return HexPoint(c.x + radius * cos(angle), c.y + radius * sin(angle))
        }
    }

    /// All cluster polygons, each a closed ring of six points, centered inside
    /// `width × height` (using the current `radius`).
    public func hexagons(inWidth width: Double, height: Double) -> [[HexPoint]] {
        cells().map { q, r in
            let c = center(q: q, r: r, originX: width / 2, originY: height / 2)
            return vertices(centeredAt: c)
        }
    }

    /// Convenience: pick the radius that fits `width × height`, then enumerate
    /// the polygons. Returns `[]` for `n == 0`.
    public static func polygons(n: Int, inWidth width: Double, height: Double, margin: Double = 8) -> [[HexPoint]] {
        guard n > 0 else { return [] }
        let r = radiusFitting(n: n, width: width, height: height, margin: margin)
        return HexGrid(n: n, radius: r).hexagons(inWidth: width, height: height)
    }
}
