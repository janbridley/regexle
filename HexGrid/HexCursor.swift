import HexGridCore

/// The three line directions through a cell.
enum Axis: Equatable {
    case row  // constant r   (edge 2)
    case column  // constant q   (edge 0)
    case diagonal  // constant q+r (edge 4)

    var edge: Int {
        switch self {
        case .row: 2
        case .column: 0
        case .diagonal: 4
        }
    }
}

/// Infers the cursor's advance direction from the player's own input.
///
/// After the user types in a cell and then taps another cell on the same line,
/// the auto-advance direction locks to that line and orientation ("A → B"). It
/// stays in effect until a later manual tap re-establishes it. Until a
/// direction is established, typing falls back to the original snake order, so
/// this is purely additive — nothing changes until the player signals intent.
///
/// This works because two distinct cells share at most one line, so the
/// two-point gesture is unambiguous.
struct HexCursor {
    private(set) var axis: Axis?
    private(set) var forward = true
    private(set) var lastTyped: Int?

    /// Call after a character is typed in `cell`; returns the next focus index.
    /// Steps to the next cell along the line in the inferred direction, in line
    /// order (filling over what's there); stays put at the end of the line.
    mutating func didType(_ cell: Int, in puzzle: HexPuzzle) -> Int {
        lastTyped = cell
        guard let axis else {
            return min(cell + 1, puzzle.order.count - 1)  // snake fallback
        }
        let line = puzzle.line(through: cell, axis: axis)
        guard let pos = line.firstIndex(of: cell) else { return cell }
        let next = forward ? pos + 1 : pos - 1
        return line.indices.contains(next) ? line[next] : cell
    }

    /// Call when the user taps `target`; may update the inferred direction.
    /// Always returns `target` (the new focus).
    mutating func didTap(_ target: Int, in puzzle: HexPuzzle) -> Int {
        if let a = lastTyped, a != target, let ax = puzzle.sharedAxis(between: a, and: target) {
            let line = puzzle.line(through: a, axis: ax)
            if let pa = line.firstIndex(of: a), let pb = line.firstIndex(of: target), pb != pa {
                axis = ax
                forward = pb > pa
            }
        }
        return target
    }

    /// Call on backspace from `cell` once it is empty; returns the cell to clear
    /// and move to. Line-aware when a direction is set, else the snake predecessor.
    mutating func backspaceTarget(from cell: Int, in puzzle: HexPuzzle) -> Int? {
        guard let axis else { return cell > 0 ? cell - 1 : nil }
        let line = puzzle.line(through: cell, axis: axis)
        guard let pos = line.firstIndex(of: cell) else { return nil }
        let neighbor = forward ? pos - 1 : pos + 1
        return line.indices.contains(neighbor) ? line[neighbor] : nil
    }
}
