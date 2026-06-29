import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore
#endif

// MARK: - Palette
private let focusOutline = Color(red: 0xF9 / 255, green: 0xF8 / 255, blue: 0x71 / 255)  // #F9F871 — focused cell
private let rowMateFill  = Color(red: 0xAF / 255, green: 0xA8 / 255, blue: 0xBA / 255)  // #AFA8BA — row-mate highlight
private let hexOutline   = Color(red: 0.6, green: 0.6, blue: 0.6)                        // inactive hex stroke
private let solvedColor  = Color(red: 0x00 / 255, green: 0xC9 / 255, blue: 0xA4 / 255)  // #00C9A4 — solved clue
private let clueColor    = Color(red: 0x4A / 255, green: 0x44 / 255, blue: 0x53 / 255)  // #4A4453 — clue text

/// Single-letter entry grid with clue strings on perimeter edges {0, 2, 4}.
/// Type to advance, Backspace to step back.
struct HexGridEntryView: View {

    let n: Int
    @State private var puzzle: HexPuzzle
    @FocusState private var focused: Int?

    init(n: Int) {
        self.n = n
        _puzzle = State(initialValue: HexPuzzle(n: n))
    }

    var body: some View {
        GeometryReader { p in
            let w = Double(p.size.width), h = Double(p.size.height)
            // Fit the cluster plus clearance so the outward clue labels
            // (top / left / upper-right) aren't clipped at the frame edge.
            // Clearance holds the longest clue (≈ 0.6·n radii out) plus a buffer.
            let clearance = 0.6 * Double(n) + 0.5
            let s = max(0, Swift.min(
                w / (HexGrid.sqrt3 * Double(2 * n - 1) + 2 * clearance),
                h / (Double(3 * n - 1) + 2 * clearance)
            ))
            let grid = HexGrid(n: n, radius: s)
            let origin = HexPoint(w / 2, h / 2)
            ZStack {
                outlines(grid: grid, s: s, origin: origin)
                labels(s: s, origin: origin)
                ForEach(0..<puzzle.order.count, id: \.self) { cell($0, grid: grid, s: s, origin: origin) }
            }
        }
        .background(Color.white)
        .onAppear { if focused == nil { focused = 0 } }
    }

    private func outlines(grid: HexGrid, s: Double, origin: HexPoint) -> some View {
        Canvas { ctx, _ in
            var mates = Path()
            for i in puzzle.rowMates(of: focused) {
                mates.addPath(hexPath(puzzle.order[i], grid, origin))
            }
            ctx.fill(mates, with: .color(rowMateFill))
            var inactive = Path()
            for (i, c) in puzzle.order.enumerated() {
                let hex = hexPath(c, grid, origin)
                if i == focused {
                    ctx.stroke(hex, with: .color(focusOutline),
                               style: StrokeStyle(lineWidth: max(1.5, s * 0.04), lineCap: .round, lineJoin: .round))
                } else { inactive.addPath(hex) }
            }
            ctx.stroke(inactive, with: .color(hexOutline),
                       style: StrokeStyle(lineWidth: max(0.5, s * 0.018), lineCap: .round, lineJoin: .round))
        }
    }

    /// Clue labels on perimeter edges {0, 2, 4}. Each label's near edge sits
    /// exactly one glyph out from the hex edge: the center is pushed past the
    /// edge by `gap + halfWidth`, so the half reaching back lands at a fixed gap.
    private func labels(s: Double, origin: HexPoint) -> some View {
        let fontSize = s * 0.5
        let charAdvance = 0.6 * fontSize          // monospace glyph advance (≈ SF Mono)
        return ForEach(Array(puzzle.clueEdges.enumerated()), id: \.offset) { idx, e in
            clueLabel(e, idx: idx, fontSize: fontSize, charAdvance: charAdvance, s: s, origin: origin)
        }
    }

    private func clueLabel(_ e: PerimeterEdge, idx: Int, fontSize: Double,
                           charAdvance: Double, s: Double, origin: HexPoint) -> ClueLabel {
        let clue = idx < puzzle.clues.count ? puzzle.clues[idx] : ""
        let off = charAdvance * (1 + Double(clue.count) / 2)   // gap + half width → 1 char out
        let mid = CGPoint(x: CGFloat(origin.x + s * e.midpoint.x), y: CGFloat(origin.y + s * e.midpoint.y))
        return ClueLabel(
            text: clue,
            size: CGFloat(fontSize),
            position: CGPoint(x: mid.x + CGFloat(e.outward.x * off), y: mid.y + CGFloat(e.outward.y * off)),
            rotation: Self.baselineAngle(e.outward),
            solved: puzzle.isSolved(at: idx))
    }

    private func cell(_ i: Int, grid: HexGrid, s: Double, origin: HexPoint) -> HexCell {
        let o = puzzle.order[i]
        let c = grid.center(q: o.q, r: o.r, originX: origin.x, originY: origin.y)
        return HexCell(letter: puzzle.letters[i], size: CGFloat(s * 0.8),
                       w: CGFloat(HexGrid.sqrt3 * s * 0.92), h: CGFloat(1.7 * s),
                       position: CGPoint(x: CGFloat(c.x), y: CGFloat(c.y)),
                       index: i, focus: $focused, onKey: { handle($0, i) })
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
        let delete = press.key == .delete || press.key == .deleteForward
            || press.characters == "\u{8}" || press.characters == "\u{7F}"
        if delete {
            if puzzle.letters[i].isEmpty, i > 0 {
                puzzle.letters[i - 1] = ""
                focused = i - 1
            } else {
                puzzle.letters[i] = ""
            }
            return .handled
        }
        if let ch = press.characters.first, ch.isLetter {
            puzzle.letters[i] = String(ch.lowercased())
            focused = Swift.min(i + 1, puzzle.order.count - 1)
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

    var body: some View {
        Text(letter)
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .frame(width: w, height: h)
            .contentShape(Rectangle())                 // make the whole frame tappable
            .focusable()
            .focusEffectDisabled()
            .focused(focus, equals: index)
            .onKeyPress(phases: .down, action: onKey)
            .onTapGesture { focus.wrappedValue = index }   // click/tap → jump focus here
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
