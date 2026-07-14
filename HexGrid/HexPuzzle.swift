import Foundation

#if canImport(HexGridCore)
    import HexGridCore
#endif

/// Scale-invariant puzzle model: topology, clues, the intended solution, and the
/// player's letters. Built once at unit radius; the owning view scales geometry to
/// pixels. Clues come from `RegexleGenerator` and are guaranteed (by construction
/// + verification) to full-match the solution lines, so every puzzle is solvable.
// NOTE: puzzles are not *uniquely* solvable, as this is NP complete.
struct HexPuzzle {
    let n: Int
    let seed: UInt64
    let topology: HexBoardTopology
    let clues: [String]
    /// Each clue's regex compiled exactly once (at init) and reused by `isSolved`
    private let compiledClues: [Regex<AnyRegexOutput>?]
    let solution: [String]  // parallel to `order`; the intended fill (hints / self-check)
    var letters: [String]   // the player's input, parallel to `order`

    var order: [(q: Int, r: Int)] { topology.order }
    var clueEdges: [PerimeterEdge] { topology.clueEdges }
    private var cellIndex: [String: Int] { topology.cellIndex }
    private var grid: HexGrid { topology.grid }

    init(n: Int, seed: UInt64, difficulty: Double = 0.5) {
        self.n = n
        self.seed = seed
        self.topology = HexBoardTopology(n: n)
        let generated = RegexleGenerator.generate(n: n, seed: seed, difficulty: difficulty)
        self.clues = generated.clues
        self.compiledClues = generated.clues.map { try? Regex($0) }
        self.solution = generated.solution
        self.letters = Array(repeating: "", count: topology.order.count)
    }

    /// Convenience with a random seed (SwiftUI previews / first launch).
    init(n: Int) {
        self.init(n: n, seed: UInt64.random(in: 0..<UInt64.max))
    }

    /// True when every clue is solved.
    var isFullySolved: Bool { (0..<clues.count).allSatisfy { isSolved(at: $0) } }

    /// Cells sharing the focused cell's horizontal row (same r) or upper-right
    /// diagonal (same q+r) — the two labeled rows it belongs to.
    func rowMates(of f: Int?) -> Set<Int> {
        guard let f, f >= 0, f < order.count else { return [] }
        let (fq, fr) = order[f]
        let diag = fq + fr
        return Set(
            order.enumerated().compactMap { (i, c) in
                (c.r == fr || c.q + c.r == diag) ? i : nil
            })
    }

    /// True when the line is fully filled and its letters match the clue's regex.
    /// Reads the line through the same `topology.lineString` chokepoint the
    /// generator used, so the reading order is identical.
    func isSolved(at clueIndex: Int) -> Bool {
        guard clueIndex >= 0, clueIndex < clues.count else { return false }
        guard let regex = compiledClues[clueIndex] else { return false }
        guard let row = topology.lineString(forClue: clueIndex, letters: letters) else { return false }
        let cells = grid.rowCells(for: clueEdges[clueIndex])
        return row.count == cells.count && ((try? regex.wholeMatch(in: row)) != nil)
    }

    // MARK: - Lines

    /// Ordered cell indices of the line through `cell` along `axis`, in the
    /// clue's reading order. (Axis is defined in HexCursor.swift.)
    func line(through cell: Int, axis: Axis) -> [Int] {
        guard cell >= 0, cell < order.count else { return [] }
        let (q, r) = order[cell]
        guard
            let edge = clueEdges.first(where: { e in
                guard e.edge == axis.edge else { return false }
                switch axis {
                case .row: return e.r == r
                case .column: return e.q == q
                case .diagonal: return e.q + e.r == q + r
                }
            })
        else { return [] }
        return grid.rowCells(for: edge).compactMap { cellIndex["\($0.q),\($0.r)"] }
    }

    /// The single line direction shared by two distinct cells, if any. Two
    /// distinct cells share at most one of {r, q, q+r}, so this is unambiguous.
    func sharedAxis(between a: Int, and b: Int) -> Axis? {
        guard a != b, a >= 0, b >= 0, a < order.count, b < order.count else { return nil }
        let (qa, ra) = order[a]
        let (qb, rb) = order[b]
        if ra == rb { return .row }
        if qa == qb { return .column }
        if qa + ra == qb + rb { return .diagonal }
        return nil
    }
}
