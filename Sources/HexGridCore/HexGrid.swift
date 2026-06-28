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

    /// Cells in reading order (top→bottom by r, left→right by q).
    public func cells() -> [(q: Int, r: Int)] {
        let k = n - 1
        guard k >= 0 else { return [] }
        var out: [(q: Int, r: Int)] = []
        out.reserveCapacity(cellCount)
        for r in -k...k {
            for q in max(-k, -k - r)...min(k, k - r) { out.append((q, r)) }
        }
        return out
    }

    /// Boustrophedon (snake) traversal: same rows as `cells()`, but each row's
    /// direction alternates so the end of one row is a visual neighbor of the
    /// start of the next (down-left as rows widen, down-right as they narrow).
    /// Every consecutive pair of cells therefore shares an edge — no leaps.
    public func cellsBoustrophedon() -> [(q: Int, r: Int)] {
        let k = n - 1
        guard k >= 0 else { return [] }
        var out: [(q: Int, r: Int)] = []
        out.reserveCapacity(cellCount)
        for row in 0...2 * k {
            let r = row - k
            let qs = Array(max(-k, -k - r)...min(k, k - r))
            let ordered = row % 2 == 0 ? qs : Array(qs.reversed())
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
    /// vertex `e` and `(e+1)%6`; edge 2 is the left vertical, edge 3 the
    /// upper-left. (0:down-right 1:down-left 2:left 3:up-left 4:up-right 5:right)
    public func perimeterEdges(originX: Double = 0, originY: Double = 0) -> [PerimeterEdge] {
        let neighbor: [(dq: Int, dr: Int)] = [(0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1), (1, 0)]
        let k = n - 1
        var out: [PerimeterEdge] = []
        for (q, r) in cells() {
            for e in 0..<6 {
                let nq = q + neighbor[e].dq, nr = r + neighbor[e].dr
                guard max(abs(nq), abs(nr), abs(nq + nr)) > k else { continue }
                let c = center(q: q, r: r, originX: originX, originY: originY)
                let v = vertices(centeredAt: c)
                let a = v[e], b = v[(e + 1) % 6]
                let mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2
                let dx = mx - c.x, dy = my - c.y
                let len = (dx * dx + dy * dy).squareRoot()
                out.append(PerimeterEdge(q: q, r: r, edge: e,
                                         midpoint: HexPoint(mx, my),
                                         outward: HexPoint(dx / len, dy / len)))
            }
        }
        return out
    }

    /// Number of cells in the row that `edge` labels: the horizontal row
    /// (constant r) for edge 2, the upper-right diagonal (constant q+r) for
    /// edge 4. Both axes share the n..2n−1..n profile.
    public func rowLength(of edge: PerimeterEdge) -> Int {
        let k = n - 1
        switch edge.edge {
        case 2: return min(k, k - edge.r) - max(-k, -k - edge.r) + 1
        case 4:
            let s = edge.q + edge.r
            return min(k, s + k) - max(-k, s - k) + 1
        default: return n
        }
    }

    /// Ordered cells of the row `edge` labels, from the perimeter cell inward:
    /// left→right for edge 2, upper-right→lower-left for edge 4.
    public func rowCells(for edge: PerimeterEdge) -> [(q: Int, r: Int)] {
        let k = n - 1
        func inside(_ q: Int, _ r: Int) -> Bool { max(abs(q), abs(r), abs(q + r)) <= k }
        var cells: [(q: Int, r: Int)] = []
        var q = edge.q, r = edge.r
        switch edge.edge {
        case 2: repeat { cells.append((q, r)); q += 1 } while inside(q, r)
        case 4:
            repeat { cells.append((q, r)); q -= 1; r += 1 } while inside(q, r)
            cells.reverse()   // read in text order: first-filled cell ↔ clue[0]
        default: cells.append((edge.q, edge.r))
        }
        return cells
    }
}
