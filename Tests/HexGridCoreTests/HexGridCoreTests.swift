import XCTest

@testable import HexGridCore

final class HexGridCoreTests: XCTestCase {

  // MARK: Cluster shape

  func testCellCountFormula() {
    // 3n² − 3n + 1, both via the property and the actual cell list.
    let expected = [1: 1, 2: 7, 3: 19, 4: 37, 5: 61, 8: 169]
    for (n, count) in expected {
      let grid = HexGrid(n: n, radius: 10)
      XCTAssertEqual(grid.cellCount, count, "n=\(n)")
      XCTAssertEqual(grid.cells().count, count, "n=\(n)")
    }
  }

  func testCellsLieWithinCubeRadiusAndReachEveryCorner() {
    let n = 5
    let k = n - 1
    let cells = HexGrid(n: n, radius: 1).cells()
    let present = Set(cells.map { "\($0.q),\($0.r)" })
    // Every cell is within cube radius k.
    for (q, r) in cells {
      XCTAssertLessThanOrEqual(
        max(abs(q), abs(r), abs(q + r)), k, "cell (\(q),\(r)) outside cluster")
    }
    // And the six corners at exactly radius k are all present.
    for (q, r) in [(k, 0), (k, -k), (0, -k), (-k, 0), (-k, k), (0, k)] {
      XCTAssertTrue(present.contains("\(q),\(r)"), "missing corner (\(q),\(r))")
    }
  }

  // MARK: Row-major traversal

  func testRowMajorRowsGrowThenShrinkAndShareConstantY() {
    let grid = HexGrid(n: 4, radius: 10)
    let chunks = contiguousRChunks(of: grid.cells())
    // Pointy-top rows: 4,5,6,7,6,5,4.
    XCTAssertEqual(chunks.map(\.count), [4, 5, 6, 7, 6, 5, 4])
    // Same r ⇒ same y: each chunk is a clean horizontal row.
    for chunk in chunks {
      XCTAssertEqual(Set(chunk.map { grid.center(q: $0.q, r: $0.r).y }).count, 1)
    }
  }

  // MARK: Sizing / fit

  func testBoundsAndRadiusFitting() {
    // Single pointy-top hex: √3·s wide, 2·s tall.
    let single = HexGrid(n: 1, radius: 10)
    XCTAssertEqual(single.boundsWidth, HexGrid.sqrt3 * 10, accuracy: 1e-9)
    XCTAssertEqual(single.boundsHeight, 20, accuracy: 1e-9)
    // Width binds when narrow, height binds when short.
    XCTAssertEqual(
      HexGrid.radiusFitting(n: 4, width: 100, height: 10_000, margin: 0),
      100 / (HexGrid.sqrt3 * Double(2 * 4 - 1)), accuracy: 1e-9)
    XCTAssertEqual(
      HexGrid.radiusFitting(n: 4, width: 10_000, height: 100, margin: 0),
      100 / Double(3 * 4 - 1), accuracy: 1e-9)
  }

  // MARK: Geometry

  func testVerticesAreSixOnCircleStartingAtThirtyDegrees() {
    let v = HexGrid(n: 1, radius: 1).vertices(centeredAt: HexPoint(0, 0))
    XCTAssertEqual(v.count, 6)
    for p in v {
      XCTAssertEqual((p.x * p.x + p.y * p.y).squareRoot(), 1, accuracy: 1e-9)
    }
    // Pointy-top first vertex sits at 30°: (√3/2, 1/2).
    XCTAssertEqual(v[0].x, HexGrid.sqrt3 / 2, accuracy: 1e-12)
    XCTAssertEqual(v[0].y, 0.5, accuracy: 1e-12)
  }

  func testCenteringInFrameIsSymmetric() {
    let n = 4
    let grid = HexGrid(n: n, radius: HexGrid.radiusFitting(n: n, width: 400, height: 400))
    let polys = grid.hexagons(inWidth: 400, height: 400)
    let xs = polys.flatMap { $0 }.map(\.x)
    let ys = polys.flatMap { $0 }.map(\.y)
    XCTAssertEqual((xs.min()! + xs.max()!) / 2, 200, accuracy: 1e-9)
    XCTAssertEqual((ys.min()! + ys.max()!) / 2, 200, accuracy: 1e-9)
  }

  func testZeroNIsEmpty() {
    XCTAssertTrue(HexGrid(n: 0, radius: 1).cells().isEmpty)
  }

  // MARK: Boustrophedon traversal

  func testBoustrophedonCoversAllCellsWithNeighborSteps() {
    let g = HexGrid(n: 4, radius: 1)
    let path = g.cellsBoustrophedon()
    // Every cell exactly once.
    XCTAssertEqual(Set(path.map { "\($0.q),\($0.r)" }).count, g.cellCount)
    // Each consecutive pair must be axial neighbors (share an edge).
    let neighbors: [(Int, Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, -1), (-1, 1)]
    for i in 1..<path.count {
      let dq = path[i].q - path[i - 1].q
      let dr = path[i].r - path[i - 1].r
      XCTAssertTrue(
        neighbors.contains { $0.0 == dq && $0.1 == dr },
        "step \(i - 1)→\(i) (\(path[i - 1])→\(path[i])) is not a neighbor")
    }
  }

  // MARK: Perimeter edges

  func testPerimeterEdgesForSingleHexAndLabeledDirections() {
    let edges = HexGrid(n: 1, radius: 1).perimeterEdges()
    XCTAssertEqual(edges.count, 6)
    XCTAssertEqual(Set(edges.map(\.edge)), Set(0...5))
    // Every labeled direction {0, 2, 4} appears on a larger cluster.
    let big = Set(HexGrid(n: 3, radius: 1).perimeterEdges().map(\.edge))
    for e in [0, 2, 4] {
      XCTAssertTrue(big.contains(e), "labeled edge \(e) missing")
    }
  }

  func testPerimeterEdgesNeighborOutsideWithUnitNormal() {
    let g = HexGrid(n: 3, radius: 1)
    let neighbor: [(Int, Int)] = [(0, 1), (-1, 1), (-1, 0), (0, -1), (1, -1), (1, 0)]
    let k = 2
    for e in g.perimeterEdges() {
      let (dq, dr) = neighbor[e.edge]
      let nq = e.q + dq
      let nr = e.r + dr
      XCTAssertGreaterThan(max(abs(nq), abs(nr), abs(nq + nr)), k)  // neighbor outside
      let len = (e.outward.x * e.outward.x + e.outward.y * e.outward.y).squareRoot()
      XCTAssertEqual(len, 1, accuracy: 1e-9)  // unit normal
    }
  }

  func testRowLengthProfileMatchesClusterRows() {
    let g = HexGrid(n: 4, radius: 1)
    let profile = [4, 5, 6, 7, 6, 5, 4].sorted()  // {4,4,5,5,6,6,7}
    for dir in [0, 2, 4] {
      let lens = g.perimeterEdges().filter { $0.edge == dir }.map { g.rowLength(of: $0) }
      XCTAssertEqual(lens.sorted(), profile, "edge \(dir)")
    }
  }

  func testRowCellsMatchRowLengthAndStayInCluster() {
    let g = HexGrid(n: 4, radius: 1)
    let k = 3
    for e in g.perimeterEdges() where [0, 2, 4].contains(e.edge) {
      let cells = g.rowCells(for: e)
      XCTAssertEqual(cells.count, g.rowLength(of: e))
      for (q, r) in cells {
        XCTAssertLessThanOrEqual(max(abs(q), abs(r), abs(q + r)), k)
      }
    }
  }
}

/// Splits the row-major cell list into contiguous runs of equal `r`.
private func contiguousRChunks(of cells: [(q: Int, r: Int)]) -> [[(q: Int, r: Int)]] {
  var out: [[(q: Int, r: Int)]] = []
  for cell in cells {
    if out.last?.last?.r == cell.r { out[out.count - 1].append(cell) } else { out.append([cell]) }
  }
  return out
}
