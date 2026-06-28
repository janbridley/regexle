import Foundation

public struct HexPoint: Equatable {
    public var x, y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

public struct PerimeterEdge {
    public let q: Int
    public let r: Int
    public let edge: Int            // 0..<6, edge between vertex `edge` and (edge+1)%6
    public let midpoint: HexPoint
    public let outward: HexPoint    // unit outward normal
}

/// Hexagonal cluster of pointy-top hexagons, `n` per side (3n²−3n+1 cells).
public struct HexGrid {

    public static let sqrt3 = 3.0.squareRoot()
    public let n: Int
    public let radius: Double

    public init(n: Int, radius: Double) {
        precondition(n >= 0 && radius >= 0)
        self.n = n; self.radius = radius
    }

    public var cellCount: Int { 3 * n * n - 3 * n + 1 }
    public var boundsWidth: Double  { Self.sqrt3 * radius * Double(2 * n - 1) }
    public var boundsHeight: Double { radius * Double(3 * n - 1) }

    public static func radiusFitting(n: Int, width: Double, height: Double, margin: Double = 8) -> Double {
        guard n > 0 else { return 0 }
        let w = max(0, width - 2 * margin), h = max(0, height - 2 * margin)
        return min(w / (sqrt3 * Double(2 * n - 1)), h / Double(3 * n - 1))
    }

    /// Cluster size minus 1 — the cube-radius of the outermost ring.
    private var k: Int { n - 1 }

    /// True when (q,r) lies inside the cluster (cube radius ≤ k).
    private func inside(_ q: Int, _ r: Int) -> Bool {
        max(abs(q), abs(r), abs(q + r)) <= k
    }

    /// The q-range of row `r`, left→right.
    private func qs(of r: Int) -> ClosedRange<Int> {
        max(-k, -k - r)...min(k, k - r)
    }

    /// Cells in reading order (top→bottom by r, left→right by q).
    public func cells() -> [(q: Int, r: Int)] {
        guard k >= 0 else { return [] }
        var out: [(q: Int, r: Int)] = []
        out.reserveCapacity(cellCount)
        for r in -k...k {
            for q in qs(of: r) { out.append((q, r)) }
        }
        return out
    }

    /// Snake traversal: same rows as `cells()`, but alternating rows reverse so
    /// the end of one row is a visual neighbor of the start of the next.
    public func cellsBoustrophedon() -> [(q: Int, r: Int)] {
        guard k >= 0 else { return [] }
        var out: [(q: Int, r: Int)] = []
        out.reserveCapacity(cellCount)
        for row in 0...2 * k {
            let r = row - k
            let ordered = row % 2 == 0 ? Array(qs(of: r)) : Array(qs(of: r).reversed())
            for q in ordered { out.append((q, r)) }
        }
        return out
    }

    public func center(q: Int, r: Int, originX: Double = 0, originY: Double = 0) -> HexPoint {
        HexPoint(originX + radius * Self.sqrt3 * (Double(q) + Double(r) / 2),
                 originY + radius * 1.5 * Double(r))
    }

    public func vertices(centeredAt c: HexPoint) -> [HexPoint] {
        (0..<6).map { k in
            let a = Double.pi / 6 + Double(k) * Double.pi / 3
            return HexPoint(c.x + radius * cos(a), c.y + radius * sin(a))
        }
    }

    public func hexagons(inWidth width: Double, height: Double) -> [[HexPoint]] {
        cells().map { center(q: $0.q, r: $0.r, originX: width / 2, originY: height / 2) }
              .map { vertices(centeredAt: $0) }
    }

    public static func polygons(n: Int, inWidth width: Double, height: Double, margin: Double = 8) -> [[HexPoint]] {
        guard n > 0 else { return [] }
        return HexGrid(n: n, radius: radiusFitting(n: n, width: width, height: height, margin: margin))
            .hexagons(inWidth: width, height: height)
    }

    /// Perimeter edges — those whose axial neighbor is outside the cluster —
    /// each with its midpoint and unit outward normal. Edge `e` runs between
    /// vertex `e` and `(e+1)%6`.
    /// (0:down-right 1:down-left 2:left 3:up-left 4:up-right 5:right)
    public func perimeterEdges(originX: Double = 0, originY: Double = 0) -> [PerimeterEdge] {
        let neighbor: [(dq: Int, dr: Int)] = [(0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1), (1, 0)]
        var out: [PerimeterEdge] = []
        for (q, r) in cells() {
            for e in 0..<6 {
                let nq = q + neighbor[e].dq, nr = r + neighbor[e].dr
                guard !inside(nq, nr) else { continue }
                let c = center(q: q, r: r, originX: originX, originY: originY)
                let v = vertices(centeredAt: c)
                let m = HexPoint((v[e].x + v[(e + 1) % 6].x) / 2, (v[e].y + v[(e + 1) % 6].y) / 2)
                let d = HexPoint(m.x - c.x, m.y - c.y)
                let len = (d.x * d.x + d.y * d.y).squareRoot()
                out.append(PerimeterEdge(q: q, r: r, edge: e, midpoint: m, outward: HexPoint(d.x / len, d.y / len)))
            }
        }
        return out
    }

    /// Number of cells in the row `edge` labels: the column (constant q) for
    /// edge 0, the horizontal row (constant r) for edge 2, the diagonal
    /// (constant q+r) for edge 4.
    public func rowLength(of edge: PerimeterEdge) -> Int {
        switch edge.edge {
        case 0:            return min(k, k - edge.q) - max(-k, -k - edge.q) + 1
        case 2:            return min(k, k - edge.r) - max(-k, -k - edge.r) + 1
        case 4: let s = edge.q + edge.r
                         return min(k, s + k) - max(-k, s - k) + 1
        default:           return n
        }
    }

    /// Ordered cells of the row `edge` labels, read in text order
    /// (first-filled cell ↔ clue[0]): left→right (edge 2), bottom→top (edge 0),
    /// upper-right→lower-left (edge 4).
    public func rowCells(for edge: PerimeterEdge) -> [(q: Int, r: Int)] {
        var cells: [(q: Int, r: Int)] = []
        var q = edge.q, r = edge.r
        switch edge.edge {
        case 0: repeat { cells.append((q, r)); r -= 1 } while inside(q, r)
                cells.reverse()
        case 2: repeat { cells.append((q, r)); q += 1 } while inside(q, r)
        case 4: repeat { cells.append((q, r)); q -= 1; r += 1 } while inside(q, r)
                cells.reverse()
        default: cells.append((q, r))
        }
        return cells
    }
}
