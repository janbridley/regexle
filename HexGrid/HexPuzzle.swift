#if canImport(HexGridCore)
    import HexGridCore
#endif

/// Scale-invariant puzzle model: topology, clues, and the player's letters.
/// Built once at unit radius; the owning view scales geometry to pixels.
struct HexPuzzle {
    let n: Int
    let order: [(q: Int, r: Int)]     // entry order (boustrophedon)
    let clueEdges: [PerimeterEdge]    // perimeter edges among {0, 2, 4}, label order
    let clues: [String]               // one clue per `clueEdges` entry
    var letters: [String]

    private let cellIndex: [String: Int]   // "q,r" → order index
    private let grid: HexGrid              // unit grid (radius 1), for row lookups

    init(n: Int) {
        self.n = n
        let g = HexGrid(n: n, radius: 1)
        self.grid = g
        let cells = g.cellsBoustrophedon()
        self.order = cells
        self.cellIndex = Dictionary(uniqueKeysWithValues:
            cells.enumerated().map { ("\($1.q),\($1.r)", $0) })
        let edges = g.perimeterEdges().filter { [0, 2, 4].contains($0.edge) }
        self.clueEdges = edges
        self.clues = edges.map { Self.randomString(g.rowLength(of: $0)) }
        self.letters = Array(repeating: "", count: cells.count)
    }

    /// Cells sharing the focused cell's horizontal row (same r) or upper-right
    /// diagonal (same q+r) — the two labeled rows it belongs to.
    func rowMates(of f: Int?) -> Set<Int> {
        guard let f, f >= 0, f < order.count else { return [] }
        let (fq, fr) = order[f]
        let diag = fq + fr
        return Set(order.enumerated().compactMap { (i, c) in
            (c.r == fr || c.q + c.r == diag) ? i : nil
        })
    }

    /// True when the row is fully filled and its letters match the clue's regex.
    func isSolved(at clueIndex: Int) -> Bool {
        guard clueIndex >= 0, clueIndex < clues.count else { return false }
        let cells = grid.rowCells(for: clueEdges[clueIndex])
        let row = cells.compactMap { cellIndex["\($0.q),\($0.r)"] }
            .map { letters[$0] }
            .joined()
        return row.count == cells.count && Self.fullMatch(clues[clueIndex], row)
    }

    // MARK: - Statics
    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz")

    /// Random lowercase letters — the clue *patterns* (plain literals today,
    /// matched through the regex engine so real patterns work later).
    private static func randomString(_ length: Int) -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    /// True if `pattern` matches the entirety of `text` (basic regex, stdlib only).
    private static func fullMatch(_ pattern: String, _ text: String) -> Bool {
        guard let regex = try? Regex(pattern) else { return false }
        return text.wholeMatch(of: regex) != nil
    }
}
