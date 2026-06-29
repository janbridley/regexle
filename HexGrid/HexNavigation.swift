#if canImport(HexGridCore)
    import HexGridCore
#endif

/// The three clue directions. Every cell lies on one line per axis. Tapping the
/// focused cell cycles `next`: row → diagonal → column → row.
enum Axis: Equatable {
    case row        // constant r   (edge 2)
    case diagonal   // constant q+r (edge 4)
    case column     // constant q   (edge 0)

    var next: Axis {
        switch self { case .row: .diagonal; case .diagonal: .column; case .column: .row }
    }

    /// Perimeter edge index this axis labels.
    var edge: Int {
        switch self { case .row: 2; case .column: 0; case .diagonal: 4 }
    }

    init?(edge: Int) {
        switch edge { case 0: self = .column; case 2: self = .row; case 4: self = .diagonal; default: return nil }
    }
}

extension HexPuzzle {

    /// Perimeter clue edges of one axis.
    func clueEdges(_ axis: Axis) -> [PerimeterEdge] {
        clueEdges.filter { $0.edge == axis.edge }
    }

    /// A line's invariant — the coordinate constant along it — used to order
    /// "the next line of this axis."
    private func lineKey(_ q: Int, _ r: Int, _ axis: Axis) -> Int {
        switch axis { case .row: r; case .column: q; case .diagonal: q + r }
    }

    /// Ordered cell indices of the line through cell `i` along `axis`, in the
    /// same reading order the clue uses (so the cursor advances with the text).
    func line(through i: Int, axis: Axis) -> [Int] {
        guard i >= 0, i < order.count else { return [] }
        let (q, r) = order[i]
        guard let edge = clueEdges(axis).first(where: { e in
            switch axis {
            case .row:      e.r == r
            case .column:   e.q == q
            case .diagonal: e.q + e.r == q + r
            }
        }) else { return [] }
        return grid.rowCells(for: edge).compactMap { cellIndex["\($0.q),\($0.r)"] }
    }

    /// The single active line through the focused cell (for highlighting).
    func activeLine(through i: Int?, axis: Axis) -> Set<Int> {
        guard let i else { return [] }
        return Set(line(through: i, axis: axis))
    }

    /// First unfilled index in `line`, in reading order.
    func firstOpen(in line: [Int]) -> Int? {
        line.first { letters[$0].isEmpty }
    }

    /// First unfilled index strictly after `i` in `line`, wrapping to the start.
    func nextOpen(after i: Int, in line: [Int]) -> Int? {
        guard let pos = line.firstIndex(of: i) else { return firstOpen(in: line) }
        let wrapped = Array(line[(pos + 1)...]) + Array(line[..<pos])
        return wrapped.first { letters[$0].isEmpty }
    }

    /// True when every cell in `line` is filled.
    func isComplete(_ line: [Int]) -> Bool {
        !line.isEmpty && line.allSatisfy { !letters[$0].isEmpty }
    }

    /// First open cell in the next same-axis line after the line containing `i`,
    /// searching forward and wrapping. Nil once every line of the axis is full.
    func firstOpenInNextLine(afterCell i: Int, axis: Axis) -> Int? {
        let lines = clueEdges(axis)
            .sorted { lineKey($0.q, $0.r, axis) < lineKey($1.q, $1.r, axis) }
            .map { grid.rowCells(for: $0).compactMap { cellIndex["\($0.q),\($0.r)"] } }
        guard let pos = lines.firstIndex(where: { $0.contains(i) }) else { return nil }
        for cells in (lines[(pos + 1)...] + lines[..<pos]) {
            if let open = firstOpen(in: cells) { return open }
        }
        return nil
    }

    /// First open cell on the line labeled by `edge` (for clue-tap selection).
    func firstOpenInLine(of edge: PerimeterEdge) -> Int? {
        firstOpen(in: grid.rowCells(for: edge).compactMap { cellIndex["\($0.q),\($0.r)"] })
    }
}
