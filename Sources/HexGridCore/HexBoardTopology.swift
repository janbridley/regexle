import Foundation

/// Shared board topology so the generator and `HexPuzzle` can never diverge on cell
/// order, clue order, or the `(q,r) → index` key format.
///
/// `clueEdges` is a stable total order for a given `n` (it comes from the
/// deterministic iteration in `HexGrid.perimeterEdges()` filtered to edges
/// `{0, 2, 4}`), and `lineString(forClue:letters:)` is the single chokepoint that
/// reads a clue's letters in exactly the order `HexGrid.rowCells(for:)` returns —
/// which is also the order the clue checker reads. Edges 0 and 4 reverse internally
/// in `rowCells`, so routing both generation and checking through this method is what
/// guarantees reading-order parity.
public struct HexBoardTopology {
  public let n: Int
  public let grid: HexGrid  // unit radius, for line lookups
  public let order: [(q: Int, r: Int)]  // boustrophedon entry order
  public let cellIndex: [String: Int]  // "q,r" → order index
  public let clueEdges: [PerimeterEdge]  // perimeter edges {0,2,4}, label order

  public init(n: Int) {
    self.n = n
    let g = HexGrid(n: n, radius: 1)
    self.grid = g
    let cells = g.cellsBoustrophedon()
    self.order = cells
    self.cellIndex = Dictionary(
      uniqueKeysWithValues: cells.enumerated().map { ("\($1.q),\($1.r)", $0) })
    self.clueEdges = g.perimeterEdges().filter { [0, 2, 4].contains($0.edge) }
  }

  /// Letters along clue `i`'s line, read in `rowCells` order (the same order the
  /// clue checker uses). Returns nil for an out-of-range index.
  public func lineString(forClue clueIndex: Int, letters: [String]) -> String? {
    guard clueIndex >= 0, clueIndex < clueEdges.count else { return nil }
    return grid.rowCells(for: clueEdges[clueIndex])
      .compactMap { cellIndex["\($0.q),\($0.r)"] }
      .map { letters[$0] }
      .joined()
  }
}
