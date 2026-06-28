import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore  // macOS executable: core is a package dependency
#endif

/// An interactive hexagonal cluster where each cell is a single-letter entry.
///
/// Each cell is a focusable `Text` that captures key presses itself (rather
/// than a `TextField`), giving precise single-letter behavior:
///   • typing a letter stores it (uppercased) and advances to the next cell in
///     reading order — right, then wrapping to the next row;
///   • Backspace clears the current cell if it has a letter, otherwise steps
///     focus back to the previous cell and clears that.
///
/// The hex outlines are stroked on a `Canvas` (line art); the focused cell is
/// highlighted. Requires macOS 14 / iOS 17 for `.onKeyPress`.
struct HexGridEntryView: View {

    let n: Int

    @State private var letters: [String]
    @FocusState private var focused: Int?

    init(n: Int) {
        self.n = n
        let count = HexGrid(n: n, radius: 1).cellCount
        _letters = State(initialValue: Array(repeating: "", count: count))
    }

    /// Cells in traversal (row-major) order — drives layout and advance.
    private var order: [(q: Int, r: Int)] { HexGrid(n: n, radius: 1).cells() }

    var body: some View {
        GeometryReader { proxy in
            let w = Double(proxy.size.width)
            let h = Double(proxy.size.height)
            let s = HexGrid.radiusFitting(n: n, width: w, height: h)
            let grid = HexGrid(n: n, radius: s)

            ZStack {
                outlines(grid: grid, width: w, height: h, radius: s)

                ForEach(0..<order.count, id: \.self) { i in
                    cell(i, grid: grid, width: w, height: h, radius: s)
                }
            }
        }
        .background(Color.white)
        .onAppear { if focused == nil { focused = 0 } }
    }

    // MARK: - Subviews

    /// Builds the focusable cell for traversal index `i`. Isolated with a
    /// concrete return type so the ForEach closure needs no inference.
    private func cell(_ i: Int, grid: HexGrid, width: Double, height: Double, radius s: Double) -> HexCell {
        let entry = order[i]
        let c = grid.center(q: entry.q, r: entry.r, originX: width / 2, originY: height / 2)
        return HexCell(
            letter: letters[i],
            fontSize: CGFloat(s * 0.8),
            cellW: CGFloat(HexGrid.sqrt3 * s * 0.92),
            cellH: CGFloat(1.7 * s),
            position: CGPoint(x: CGFloat(c.x), y: CGFloat(c.y)),
            index: i,
            focus: $focused,
            onKey: { handle($0, at: i) }
        )
    }

    /// Hex outlines (line art); the focused cell is highlighted.
    private func outlines(grid: HexGrid, width: Double, height: Double, radius s: Double) -> some View {
        Canvas { context, _ in
            var inactive = Path()
            let baseColor = Color(red: 0.6, green: 0.6, blue: 0.6)
            for (i, cell) in order.enumerated() {
                let hex = path(for: cell, in: grid, originX: width / 2, originY: height / 2)
                if i == focused {
                    context.stroke(
                        hex,
                        with: .color(.accentColor),
                        style: StrokeStyle(lineWidth: max(1.5, s * 0.04), lineCap: .round, lineJoin: .round)
                    )
                } else {
                    inactive.addPath(hex)
                }
            }
            context.stroke(
                inactive,
                with: .color(baseColor),
                style: StrokeStyle(lineWidth: max(0.5, s * 0.018), lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: - Key handling

    /// Single-letter entry + navigation. Returns `.handled` when we consume the
    /// key, `.ignored` to let it pass through (and be ignored by the empty cell).
    private func handle(_ press: KeyPress, at i: Int) -> KeyPress.Result {
        // Backspace (⌫) or forward-delete (⌦): clear current; if already empty,
        // step back and clear the previous cell. The key can arrive as the named
        // KeyEquivalent or as a raw control char (\u{8} BS / \u{7F} DEL), so we
        // accept any of them.
        let isDelete = press.key == .delete || press.key == .deleteForward
            || press.characters == "\u{8}" || press.characters == "\u{7F}"
        if isDelete {
            if !letters[i].isEmpty {
                letters[i] = ""
            } else {
                let prev = i - 1
                if prev >= 0 {
                    letters[prev] = ""
                    focused = prev
                }
            }
            return .handled
        }

        // A letter: store it (uppercased) and advance.
        if let ch = press.characters.first, ch.isLetter {
            letters[i] = String(ch.lowercased())
            focused = Swift.min(i + 1, order.count - 1)   // clamp so Backspace still works at the end
            return .handled
        }

        return .ignored
    }

    // MARK: - Helpers

    /// Builds the closed hex path for a cell.
    private func path(for cell: (q: Int, r: Int), in grid: HexGrid, originX: Double, originY: Double) -> Path {
        let center = grid.center(q: cell.q, r: cell.r, originX: originX, originY: originY)
        var path = Path()
        for (k, p) in grid.vertices(centeredAt: center).enumerated() {
            let point = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
            if k == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// One focusable single-letter cell, positioned at its hexagon center. Isolated
/// into its own type so the modifier chain + `.onKeyPress` type-check cleanly.
private struct HexCell: View {
    let letter: String
    let fontSize: CGFloat
    let cellW: CGFloat
    let cellH: CGFloat
    let position: CGPoint
    let index: Int
    let focus: FocusState<Int?>.Binding
    let onKey: (KeyPress) -> KeyPress.Result

    var body: some View {
        Text(letter)
            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .frame(width: cellW, height: cellH)
            .focusable()
            .focusEffectDisabled()
            .focused(focus, equals: index)
            .onKeyPress(action: onKey)
            .position(x: position.x, y: position.y)
    }
}
