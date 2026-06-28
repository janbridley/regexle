import XCTest
@testable import HexGridCore

final class HexGridCoreTests: XCTestCase {

    // MARK: Cluster shape

    func testCellCountFormula() {
        // 3n² − 3n + 1
        let expected = [1: 1, 2: 7, 3: 19, 4: 37, 5: 61, 8: 169]
        for (n, count) in expected {
            let grid = HexGrid(n: n, radius: 10)
            XCTAssertEqual(grid.cellCount, count, "n=\(n)")
            XCTAssertEqual(grid.cells().count, count, "n=\(n)")
        }
    }

    func testEveryCellWithinCubeRadius() {
        let n = 5
        let k = n - 1
        let grid = HexGrid(n: n, radius: 1)
        for (q, r) in grid.cells() {
            let dist = max(abs(q), abs(r), abs(q + r))
            XCTAssertLessThanOrEqual(dist, k, "cell (\(q),\(r)) outside cluster")
        }
    }

    func testClusterHasSixCornersAtRadiusNMinus1() {
        let n = 4
        let k = n - 1
        let present = Set(HexGrid(n: n, radius: 1).cells().map { "\($0.q),\($0.r)" })
        let corners = [(k, 0), (k, -k), (0, -k), (-k, 0), (-k, k), (0, k)]
        for (q, r) in corners {
            XCTAssertTrue(present.contains("\(q),\(r)"), "missing corner (\(q),\(r))")
        }
    }

    // MARK: Row-major traversal order

    func testTraversalIsRowMajorWithGrowingShrinkingRows() {
        // Pointy-top cluster rows grow to the middle then shrink: n..2n-1..n.
        let n = 4
        let cells = HexGrid(n: n, radius: 1).cells()
        // Group consecutive cells sharing the same r.
        var rows: [[Int]] = []
        for (_, r) in cells {
            if rows.last?.first == r { rows[rows.count - 1].append(r) }
            else { rows.append([r]) }
        }
        XCTAssertEqual(rows.map(\.count), [4, 5, 6, 7, 6, 5, 4])
    }

    func testTraversalRowsShareConstantY() {
        // Same r ⇒ same y (pointy-top): a clean horizontal row.
        let grid = HexGrid(n: 4, radius: 10)
        let cells = grid.cells()
        for chunk in contiguousRChunks(of: cells) where !chunk.isEmpty {
            let ys = Set(chunk.map { grid.center(q: $0.q, r: $0.r).y })
            XCTAssertEqual(ys.count, 1, "row r=\(chunk[0].r) is not horizontal")
        }
    }

    // MARK: Sizing / fit

    func testBoundsForSinglePointyTopHex() {
        let grid = HexGrid(n: 1, radius: 10)
        XCTAssertEqual(grid.boundsWidth,  HexGrid.sqrt3 * 10, accuracy: 1e-9) // √3·s
        XCTAssertEqual(grid.boundsHeight, 20, accuracy: 1e-9)                 // 2s
    }

    func testRadiusFittingRespectsWidthAndHeightBounds() {
        // Tall-but-narrow frame: width binds.
        let r2 = HexGrid.radiusFitting(n: 4, width: 100, height: 10_000, margin: 0)
        XCTAssertEqual(r2, 100 / (HexGrid.sqrt3 * Double(2 * 4 - 1)), accuracy: 1e-9)
        // Wide-but-short frame: height binds.
        let r = HexGrid.radiusFitting(n: 4, width: 10_000, height: 100, margin: 0)
        XCTAssertEqual(r, 100 / Double(3 * 4 - 1), accuracy: 1e-9)
    }

    // MARK: Geometry

    func testVerticesAreSixAndOnCircle() {
        let grid = HexGrid(n: 1, radius: 10)
        let v = grid.vertices(centeredAt: HexPoint(0, 0))
        XCTAssertEqual(v.count, 6)
        for p in v {
            XCTAssertEqual((p.x * p.x + p.y * p.y).squareRoot(), 10, accuracy: 1e-9)
        }
    }

    func testPointyTopFirstVertexAtThirtyDegrees() {
        // Pointy-top first vertex sits at 30°, not 0°.
        let grid = HexGrid(n: 1, radius: 1)
        let v = grid.vertices(centeredAt: HexPoint(0, 0))
        XCTAssertEqual(v[0].x, HexGrid.sqrt3 / 2, accuracy: 1e-12)
        XCTAssertEqual(v[0].y, 0.5, accuracy: 1e-12)
    }

    func testCenteringInFrameIsSymmetric() {
        let n = 4
        let grid = HexGrid(n: n, radius: HexGrid.radiusFitting(n: n, width: 400, height: 400))
        let polygons = grid.hexagons(inWidth: 400, height: 400)
        let xs = polygons.flatMap { $0 }.map(\.x)
        let ys = polygons.flatMap { $0 }.map(\.y)
        XCTAssertEqual((xs.min()! + xs.max()!) / 2, 200, accuracy: 1e-9)
        XCTAssertEqual((ys.min()! + ys.max()!) / 2, 200, accuracy: 1e-9)
    }

    func testPolygonsHelperMatchesExplicitGrid() {
        let n = 3
        let r = HexGrid.radiusFitting(n: n, width: 500, height: 500)
        let explicit = HexGrid(n: n, radius: r).hexagons(inWidth: 500, height: 500)
        let helper   = HexGrid.polygons(n: n, inWidth: 500, height: 500)
        XCTAssertEqual(explicit, helper)
    }

    func testZeroNIsEmpty() {
        XCTAssertTrue(HexGrid(n: 0, radius: 1).cells().isEmpty)
        XCTAssertTrue(HexGrid.polygons(n: 0, inWidth: 100, height: 100).isEmpty)
    }
}

/// Splits the row-major cell list into contiguous runs of equal `r`.
private func contiguousRChunks(of cells: [(q: Int, r: Int)]) -> [[(q: Int, r: Int)]] {
    var out: [[(q: Int, r: Int)]] = []
    for cell in cells {
        if out.last?.last?.r == cell.r { out[out.count - 1].append(cell) }
        else { out.append([cell]) }
    }
    return out
}
