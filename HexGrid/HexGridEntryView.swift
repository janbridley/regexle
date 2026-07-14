import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore
#endif

// MARK: - Palette
let focusOutline = Color(red: 0xF9 / 255, green: 0xF8 / 255, blue: 0x71 / 255)  // #F9F871 — focused cell
let rowMateFill = Color(red: 0xAF / 255, green: 0xA8 / 255, blue: 0xBA / 255)  // #AFA8BA — row-mate highlight
let hexOutline = Color(red: 0.6, green: 0.6, blue: 0.6)  // inactive hex stroke
let solvedColor = Color(red: 0x00 / 255, green: 0xC9 / 255, blue: 0xA4 / 255)  // #00C9A4 — solved clue
let clueColor = Color(red: 0x4A / 255, green: 0x44 / 255, blue: 0x53 / 255)  // #4A4453 — clue text

/// Margin (in hex-radius units) reserved around the board for clue labels. This is
/// the cell-vs-text tradeoff knob: larger = smaller cells, larger clue text (and
/// vice versa). Font is capped at the cell-letter size, so it never dwarfs the grid.
private let clueClearance: Double = 6.0

/// Single-letter entry grid with clue strings on perimeter edges {0, 2, 4}.
/// Type to advance, Backspace to step back.
struct HexGridEntryView: View {

    let n: Int
    let onNext: () -> Void
    let onLettersChange: ([String]) -> Void
    @State private var puzzle: HexPuzzle
    @State private var cursor = HexCursor()
    @State private var solveProgress: CGFloat  // 0→1 reveal of the solve border
    @State private var pulse = false  // celebration pulse after the outline completes
    @State private var showWin = false  // reveals the "You Win!" card
    @FocusState private var focused: Int?

    init(n: Int, counter: Int, locked: Bool, initialLetters: [String],
         onNext: @escaping () -> Void, onLettersChange: @escaping ([String]) -> Void) {
        self.n = n
        self.onNext = onNext
        self.onLettersChange = onLettersChange
        _puzzle = State(initialValue: HexPuzzle(
            n: n, counter: counter, initialLetters: initialLetters, locked: locked))
        // A locked (historically solved) puzzle shows its border already drawn, with no
        // animation — it starts solved, so `.onChange` never fires and no popup appears.
        _solveProgress = State(initialValue: locked ? 1 : 0)
    }

    var body: some View {
        GeometryReader { p in
            let w = Double(p.size.width)
            let h = Double(p.size.height)
            // Fit the cluster plus a fixed margin so the outward clue labels
            // (top / left / upper-right) aren't clipped at the frame edge.
            let clearance = clueClearance
            let s = max(
                0,
                min(
                    w / (HexGrid.sqrt3 * Double(2 * n - 1) + 2 * clearance),
                    h / (Double(3 * n - 1) + 2 * clearance)
                ))
            let grid = HexGrid(n: n, radius: s)
            let origin = HexPoint(w / 2, h / 2)
            ZStack {
                outlines(grid: grid, s: s, origin: origin)
                labels(s: s, origin: origin)
                ForEach(0..<puzzle.order.count, id: \.self) {
                    cell($0, grid: grid, s: s, origin: origin)
                }
                // Solve animation: a thick green border drawn around the board outline,
                // starting at the top-left, over `n` seconds.
                Path {
                    let pts = grid.outlineVertices(originX: origin.x, originY: origin.y)
                    guard let first = pts.first else { return }
                    $0.move(to: CGPoint(x: first.x, y: first.y))
                    for p in pts.dropFirst() { $0.addLine(to: CGPoint(x: p.x, y: p.y)) }
                }
                .trim(from: 0, to: solveProgress)
                .stroke(solvedColor, style: StrokeStyle(
                    lineWidth: max(2, s * 0.12), lineCap: .round, lineJoin: .round))
            }
            .scaleEffect(pulse ? 1.06 : 1.0)  // celebration pulse after the outline completes
        }
        .background(Color.white)
        .onAppear { if focused == nil { focused = 0 } }
        .onChange(of: puzzle.isFullySolved) { _, solved in
            if solved {
                withAnimation(.linear(duration: Double(n))) {
                    solveProgress = 1
                } completion: {
                    guard puzzle.isFullySolved else { return }
                    // Pulse the board twice (up-down × 2); the "You Win!" card rises
                    // with the second pulse.
                    withAnimation(.easeInOut(duration: 0.4).repeatCount(4, autoreverses: true)) {
                        pulse = true
                    } completion: {
                        pulse = false  // model back to rest (1.0), matching the autoreverse end
                    }
                    withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                        showWin = true
                    }
                }
            } else {
                solveProgress = 0  // unsolved (e.g. edited) → reset, ready to replay
                pulse = false
                showWin = false
            }
        }
        .overlay {
            if showWin {
                ZStack {
                    Rectangle().fill(.black.opacity(0.4))
                    VStack(spacing: 16) {
                        Text("You Win!")
                            .font(.largeTitle).bold()
                            .foregroundStyle(solvedColor)
                        Button("Next Puzzle") { onNext() }
                            .buttonStyle(.borderedProminent)
                            .tint(solvedColor)
                    }
                    .padding(32)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                }
                .transition(.opacity)
            }
        }
    }

    private func outlines(grid: HexGrid, s: Double, origin: HexPoint) -> some View {
        Canvas { ctx, _ in
            var mates = Path()
            for i in puzzle.rowMates(of: focused) {
                mates.addPath(hexPath(puzzle.order[i], grid, origin))
            }
            ctx.fill(mates, with: .color(rowMateFill))
            var inactive = Path()
            var focusPath: Path?
            for (i, c) in puzzle.order.enumerated() {
                let hex = hexPath(c, grid, origin)
                if i == focused {
                    focusPath = hex
                } else {
                    inactive.addPath(hex)
                }
            }
            // Inactive outlines first, then the focused yellow outline last so it sits
            // on top of the shared edges with its neighbors.
            ctx.stroke(
                inactive, with: .color(hexOutline),
                style: StrokeStyle(
                    lineWidth: max(0.5, s * 0.018), lineCap: .round, lineJoin: .round))
            if let focusPath {
                ctx.stroke(
                    focusPath, with: .color(focusOutline),
                    style: StrokeStyle(
                        lineWidth: max(1.5, s * 0.04), lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// Clue labels on perimeter edges {0, 2, 4}. Each label's near edge sits
    /// exactly one glyph out from the hex edge: the center is pushed past the
    /// edge by `gap + halfWidth`, so the half reaching back lands at a fixed gap.
    private func labels(s: Double, origin: HexPoint) -> some View {
        // Size the font so the longest clue fills the margin (`clueClearance·s`),
        // capped at the cell-letter size so clues never dwarf the grid. Because the
        // cap no longer shrinks with `s`, raising `clueClearance` reliably trades
        // smaller cells for larger text.
        let longest = max(1, puzzle.clues.map { $0.count }.max() ?? 1)
        let fitAdvance = clueClearance * s / Double(longest + 1)
        let charAdvance = min(0.48 * s, fitAdvance)  // ≈ SF Mono glyph advance
        let fontSize = charAdvance / 0.6
        return ForEach(Array(puzzle.clueEdges.enumerated()), id: \.offset) { idx, e in
            clueLabel(
                e, idx: idx, fontSize: fontSize, charAdvance: charAdvance, s: s, origin: origin)
        }
    }

    private func clueLabel(
        _ e: PerimeterEdge, idx: Int, fontSize: Double,
        charAdvance: Double, s: Double, origin: HexPoint
    ) -> ClueLabel {
        let clue = idx < puzzle.clues.count ? puzzle.clues[idx] : ""
        let off = charAdvance * (1 + Double(clue.count) / 2)  // gap + half width → 1 char out
        let mid = CGPoint(
            x: CGFloat(origin.x + s * e.midpoint.x), y: CGFloat(origin.y + s * e.midpoint.y))
        return ClueLabel(
            text: clue,
            size: CGFloat(fontSize),
            position: CGPoint(
                x: mid.x + CGFloat(e.outward.x * off), y: mid.y + CGFloat(e.outward.y * off)),
            rotation: Self.baselineAngle(e.outward),
            solved: puzzle.isSolved(at: idx))
    }

    private func cell(_ i: Int, grid: HexGrid, s: Double, origin: HexPoint) -> HexCell {
        let o = puzzle.order[i]
        let c = grid.center(q: o.q, r: o.r, originX: origin.x, originY: origin.y)
        return HexCell(
            letter: puzzle.letters[i], size: CGFloat(s * 0.8),
            w: CGFloat(HexGrid.sqrt3 * s * 0.92), h: CGFloat(1.7 * s),
            position: CGPoint(x: CGFloat(c.x), y: CGFloat(c.y)),
            index: i, focus: $focused,
            onKey: { handle($0, i) },
            onTap: { focused = cursor.didTap(i, in: puzzle) })
    }

    private func hexPath(_ c: (q: Int, r: Int), _ grid: HexGrid, _ origin: HexPoint) -> Path {
        let ctr = grid.center(q: c.q, r: c.r, originX: origin.x, originY: origin.y)
        var path = Path()
        for (k, v) in grid.vertices(centeredAt: ctr).enumerated() {
            let pt = CGPoint(x: CGFloat(v.x), y: CGFloat(v.y))
            if k == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    /// Text baseline along the outward normal, normalized to a readable tilt.
    private static func baselineAngle(_ normal: HexPoint) -> Double {
        var a = atan2(normal.y, normal.x) * 180 / .pi
        while a > 90 { a -= 180 }
        while a < -90 { a += 180 }
        return a
    }

    private func handle(_ press: KeyPress, _ i: Int) -> KeyPress.Result {
        // Historically solved puzzles are immutable at the view layer (the store rejects
        // writes for non-active counters too).
        if puzzle.locked { return .ignored }
        let delete =
            press.key == .delete || press.key == .deleteForward
            || press.characters == "\u{8}" || press.characters == "\u{7F}"
        if delete {
            if !puzzle.letters[i].isEmpty {
                puzzle.letters[i] = ""
            } else if let prev = cursor.backspaceTarget(from: i, in: puzzle) {
                puzzle.letters[prev] = ""
                focused = prev
            }
            onLettersChange(puzzle.letters)
            return .handled
        }
        if let ch = press.characters.first, ch.isLetter {
            puzzle.letters[i] = String(ch.uppercased())
            focused = cursor.didType(i, in: puzzle)
            onLettersChange(puzzle.letters)
            return .handled
        }
        return .ignored
    }
}

private struct HexCell: View {
    let letter: String
    let size: CGFloat
    let w: CGFloat
    let h: CGFloat
    let position: CGPoint
    let index: Int
    let focus: FocusState<Int?>.Binding
    let onKey: (KeyPress) -> KeyPress.Result
    let onTap: () -> Void

    var body: some View {
        Text(letter)
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .frame(width: w, height: h)
            .contentShape(Rectangle())  // make the whole frame tappable
            .focusable()
            .focusEffectDisabled()
            .focused(focus, equals: index)
            .onKeyPress(phases: .down, action: onKey)
            .onTapGesture(perform: onTap)  // tap → cursor infers direction
            .position(position)
    }
}

private struct ClueLabel: View {
    let text: String
    let size: CGFloat
    let position: CGPoint
    let rotation: Double
    let solved: Bool

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: solved ? .bold : .regular, design: .monospaced))
            .foregroundStyle(solved ? solvedColor : clueColor)
            .rotationEffect(.degrees(rotation))
            .position(position)
    }
}
