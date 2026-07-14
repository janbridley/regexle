import XCTest

@testable import HexGridCore

final class RegexleGeneratorTests: XCTestCase {

  // MARK: - Parity invariant (load-bearing)
  // Every clue must full-match its solution line. This test pins the invariant.

  func testParityInvariant() {
    let seeds: [UInt64] = [0, 1, 7, 42, 9999, 0xDEAD_BEEF_CAFE_BABE]
    for n in 1...5 {
      for seed in seeds {
        let puzzle = RegexleGenerator.generate(n: n, seed: seed)
        let topo = HexBoardTopology(n: n)
        XCTAssertEqual(puzzle.clues.count, topo.clueEdges.count, "n=\(n) seed=\(seed)")
        XCTAssertEqual(puzzle.solution.count, topo.order.count, "n=\(n) seed=\(seed)")
        for i in 0..<puzzle.clues.count {
          let line = topo.lineString(forClue: i, letters: puzzle.solution)!
          XCTAssertTrue(
            RegexleGenerator.fullMatches(puzzle.clues[i], line),
            "n=\(n) seed=\(seed) clue \(i) «\(puzzle.clues[i])» must full-match «\(line)»")
        }
      }
    }
  }

  // Larger board still satisfies parity (fewer seeds — generation is slower).
  func testParityInvariantLargeBoard() {
    let puzzle = RegexleGenerator.generate(n: 7, seed: 12345)
    let topo = HexBoardTopology(n: 7)
    for i in 0..<puzzle.clues.count {
      let line = topo.lineString(forClue: i, letters: puzzle.solution)!
      XCTAssertTrue(
        RegexleGenerator.fullMatches(puzzle.clues[i], line),
        "clue \(i) «\(puzzle.clues[i])» must full-match «\(line)»")
    }
  }

  // MARK: - Determinism

  func testDeterministicGivenSeed() {
    XCTAssertEqual(
      RegexleGenerator.generate(n: 4, seed: 7),
      RegexleGenerator.generate(n: 4, seed: 7))
  }

  func testDifferentSeedsDiffer() {
    XCTAssertNotEqual(
      RegexleGenerator.generate(n: 4, seed: 1),
      RegexleGenerator.generate(n: 4, seed: 2))
  }

  // MARK: - RNG

  func testSFC64Deterministic() {
    var r1 = SFC64(seed: 1234)
    var r2 = SFC64(seed: 1234)
    for _ in 0..<1000 {
      XCTAssertEqual(r1.next(), r2.next())
    }
  }

  func testSFC64SeedSensitivity() {
    var r1 = SFC64(seed: 1)
    var r2 = SFC64(seed: 2)
    var differ = false
    for _ in 0..<100 {
      if r1.next() != r2.next() {
        differ = true
        break
      }
    }
    XCTAssertTrue(differ)
  }

  // MARK: - Geometry / line extraction

  func testClueCountIsThreeAxes() {
    // 3 axes × (2n−1) lines each.
    for n in 1...5 {
      XCTAssertEqual(HexBoardTopology(n: n).clueEdges.count, 3 * (2 * n - 1), "n=\(n)")
    }
  }

  func testLineLengthsMatchGeometry() {
    let n = 4
    let topo = HexBoardTopology(n: n)
    let puzzle = RegexleGenerator.generate(n: n, seed: 5)
    for i in 0..<topo.clueEdges.count {
      let line = topo.lineString(forClue: i, letters: puzzle.solution)!
      XCTAssertEqual(line.count, topo.grid.rowLength(of: topo.clueEdges[i]), "clue \(i)")
    }
  }

  // A cell's letter must be the same letter whichever of its 3 lines reads it.
  func testLinesAgreeAtIntersections() {
    let n = 3
    let topo = HexBoardTopology(n: n)
    let puzzle = RegexleGenerator.generate(n: n, seed: 99)
    for (cellIndex, cell) in topo.order.enumerated() {
      let cellLetter = puzzle.solution[cellIndex]
      for i in 0..<topo.clueEdges.count {
        let lineCells = topo.grid.rowCells(for: topo.clueEdges[i])
        guard let linePos = lineCells.firstIndex(where: { $0.q == cell.q && $0.r == cell.r })
        else { continue }
        let line = topo.lineString(forClue: i, letters: puzzle.solution)!
        XCTAssertEqual(
          String(Array(line)[linePos]), cellLetter,
          "cell (\(cell.q),\(cell.r)) disagrees on clue \(i)")
      }
    }
  }

  // MARK: - Transforms (faithful port of regexle's RegexGenerator)

  func testAddBrackets() {
    XCTAssertEqual(RegexleGenerator.addBrackets("(PH|TH)"), "([PT]H)")
    XCTAssertEqual(RegexleGenerator.addBrackets("(EL|EB)"), "(E[LB])")
    XCTAssertEqual(RegexleGenerator.addBrackets("(ABC|DEF)"), "(ABC|DEF)")
  }

  func testRemoveDoubleAsterisks() {
    XCTAssertEqual(RegexleGenerator.removeDoubleAsterisks(".*.*"), ".*")
    XCTAssertEqual(RegexleGenerator.removeDoubleAsterisks(".*ABC.*.*"), ".*ABC.*")
    XCTAssertEqual(RegexleGenerator.removeDoubleAsterisks(".*"), ".*")
  }

  func testMiddleQuestion() {
    XCTAssertEqual(RegexleGenerator.middleQuestion("(MY|.*|Y)"), "(M?Y|.*)")
    XCTAssertEqual(RegexleGenerator.middleQuestion("(MY|Y)"), "(M?Y)")
  }

  func testEndQuestion() {
    XCTAssertEqual(RegexleGenerator.endQuestion("(PM|.*|P)"), "(PM?|.*)")
    XCTAssertEqual(RegexleGenerator.endQuestion("(PM|P)"), "(PM?)")
  }

  func testRemoveDuplicateChars() {
    XCTAssertEqual(RegexleGenerator.removeDuplicateChars("(HD|.*|HD)"), "(HD|.*)")
  }

  // MARK: - Two-word seeding (decorrelates puzzle sizes via the `b` lane)

  func testSFC64SecondWordDeterminism() {
    var r1 = SFC64(seed: 7, second: 4)
    var r2 = SFC64(seed: 7, second: 4)
    for _ in 0..<1000 { XCTAssertEqual(r1.next(), r2.next()) }
  }

  func testSFC64SecondWordDiverges() {
    var r1 = SFC64(seed: 7, second: 4)
    var r2 = SFC64(seed: 7, second: 5)
    var differ = false
    for _ in 0..<100 {
      if r1.next() != r2.next() {
        differ = true
        break
      }
    }
    XCTAssertTrue(differ)
  }

  // `second == 0` reproduces the single-seed stream, so the default matches
  // `init(seed:)`.
  func testSFC64SecondDefaultMatchesSingleSeed() {
    var r1 = SFC64(seed: 1234)
    var r2 = SFC64(seed: 1234, second: 0)
    for _ in 0..<1000 { XCTAssertEqual(r1.next(), r2.next()) }
  }

  // Same counter, different n ⇒ different puzzle (sizes are uncorrelated).
  func testSecondSeedDecorrelatesSizes() {
    XCTAssertNotEqual(
      RegexleGenerator.generate(n: 4, seed: 1, secondSeed: 4),
      RegexleGenerator.generate(n: 4, seed: 1, secondSeed: 5))
  }

  // The app's seed scheme: seed = counter, secondSeed = n.
  func testCounterReproducibility() {
    let puzzle: (Int) -> GeneratedPuzzle = { k in
      RegexleGenerator.generate(n: 4, seed: UInt64(k), secondSeed: 4)
    }
    XCTAssertEqual(puzzle(7), puzzle(7))  // deterministic
    XCTAssertNotEqual(puzzle(7), puzzle(8))  // different counter ⇒ different puzzle
  }
}
