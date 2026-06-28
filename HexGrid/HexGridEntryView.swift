import SwiftUI
import Foundation

#if canImport(HexGridCore)
    import HexGridCore
#endif

// MARK: - Palette
private let focusOutline = Color(red: 0xF9 / 255, green: 0xF8 / 255, blue: 0x71 / 255)  // #71618D — focused cell
private let rowMateFill  = Color(red: 0xAF / 255, green: 0xA8 / 255, blue: 0xBA / 255)  // #AFA8BA — row-mate highlight
private let hexOutline   = Color(red: 0.6, green: 0.6, blue: 0.6)                        // inactive hex stroke
private let solvedColor  = Color(red: 0x00 / 255, green: 0xC9 / 255, blue: 0xA4 / 255)  // #00C9A4 — solved clue
private let clueColor    = Color(red: 0x4A / 255, green: 0x44 / 255, blue: 0x53 / 255)  // #4A4453 — clue text

/// Single-letter entry grid with clue strings on perimeter edges {0, 2, 4}.
/// Type to advance, Backspace to step back.
struct HexGridEntryView: View {

    let n: Int
    private let order: [(q: Int, r: Int)]          // row-major: 4,5,6,7,6,5,4 …
    private let cellIndex: [String: Int]           // "q,r" → traversal index
    @State private var letters: [String]
    @State private var clues: [String]
    @FocusState private var focused: Int?

    init(n: Int) {
        self.n = n
        let g = HexGrid(n: n, radius: 1)
        let cells = g.cellsBoustrophedon()
        self.order = cells
        self.cellIndex = Dictionary(uniqueKeysWithValues: cells.enumerated().map { ("\($1.q),\($1.r)", $0) })
        _letters = State(initialValue: Array(repeating: "", count: cells.count))
        _clues = State(initialValue: Self.assignClueEdges(g.perimeterEdges())
            .map { Self.randomString(g.rowLength(of: $0)) })
    }

    var body: some View {
        GeometryReader { p in
            let w = Double(p.size.width), h = Double(p.size.height)
            // Fit the cluster plus s-scaled clearance so the outward clue labels
            // (top / left / upper-right) aren't clipped at the frame edge.
            // Clearance must hold the longest clue (≈ 0.6·n radii out from the
            // edge) plus a small buffer, so far ends aren't clipped.
            let clearance = 0.6 * Double(n) + 0.5
            let s = max(0, Swift.min(
                w / (HexGrid.sqrt3 * Double(2 * n - 1) + 2 * clearance),
                h / (Double(3 * n - 1) + 2 * clearance)
            ))
            let grid = HexGrid(n: n, radius: s)
            ZStack {
                outlines(grid, w, h, s, highlight: rowMates(of: focused))
                labels(grid, w, h, s)
                ForEach(0..<order.count, id: \.self) { cell($0, grid, w, h, s) }
            }
        }
        .background(Color.white)
        .onAppear { if focused == nil { focused = 0 } }
    }

    /// Cells sharing the focused cell's horizontal row (same `r`) or upper-right
    /// diagonal (same `q+r`) — the two labeled rows it belongs to.
    private func rowMates(of f: Int?) -> Set<Int> {
        guard let f, f < order.count else { return [] }
        let (fq, fr) = order[f]
        let diag = fq + fr
        return Set(order.enumerated().compactMap { (i, c) in
            (c.r == fr || c.q + c.r == diag) ? i : nil
        })
    }

    private func outlines(_ grid: HexGrid, _ w: Double, _ h: Double, _ s: Double, highlight: Set<Int>) -> some View {
        Canvas { ctx, _ in
            var mates = Path()
            for i in highlight {
                mates.addPath(hexPath(order[i], grid, w / 2, h / 2))
            }
            ctx.fill(mates, with: .color(rowMateFill))
            var inactive = Path()
            for (i, c) in order.enumerated() {
                let hex = hexPath(c, grid, w / 2, h / 2)
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
    private func labels(_ grid: HexGrid, _ w: Double, _ h: Double, _ s: Double) -> some View {
        let edges = Self.assignClueEdges(grid.perimeterEdges(originX: w / 2, originY: h / 2))
        return ForEach(Array(edges.enumerated()), id: \.offset) { idx, e in
            clueLabel(grid, e, idx, s)
        }
    }

    private func clueLabel(_ grid: HexGrid, _ e: PerimeterEdge, _ idx: Int, _ s: Double) -> ClueLabel {
        let fontSize = s * 0.5
        let charAdvance = 0.6 * fontSize          // monospace glyph advance (≈ SF Mono)
        let clue = idx < clues.count ? clues[idx] : ""
        // gap (1 char) + half the text width → near edge sits exactly 1 char out.
        let off = charAdvance * (1 + Double(clue.count) / 2)
        return ClueLabel(
            text: clue,
            size: CGFloat(fontSize),
            position: CGPoint(x: CGFloat(e.midpoint.x + e.outward.x * off),
                              y: CGFloat(e.midpoint.y + e.outward.y * off)),
            rotation: Self.baselineAngle(e.outward),
            solved: isSolved(grid, edge: e, at: idx))
    }

    /// True when the row is fully filled and its letters match the clue's regex.
    private func isSolved(_ grid: HexGrid, edge: PerimeterEdge, at idx: Int) -> Bool {
        guard idx < clues.count else { return false }
        let cells = grid.rowCells(for: edge)
        let row = cells.compactMap { cellIndex["\($0.q),\($0.r)"] }
            .map { $0 < letters.count ? letters[$0] : "" }
            .joined()
        return row.count == cells.count && Self.fullMatch(clues[idx], row)
    }

    private func cell(_ i: Int, _ grid: HexGrid, _ w: Double, _ h: Double, _ s: Double) -> HexCell {
        let c = grid.center(q: order[i].q, r: order[i].r, originX: w / 2, originY: h / 2)
        return HexCell(letter: letters[i], size: CGFloat(s * 0.8),
                       w: CGFloat(HexGrid.sqrt3 * s * 0.92), h: CGFloat(1.7 * s),
                       position: CGPoint(x: CGFloat(c.x), y: CGFloat(c.y)),
                       index: i, focus: $focused, onKey: { handle($0, i) })
    }

    private func hexPath(_ c: (q: Int, r: Int), _ grid: HexGrid, _ ox: Double, _ oy: Double) -> Path {
        let ctr = grid.center(q: c.q, r: c.r, originX: ox, originY: oy)
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

    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz")

    /// Random lowercase letters. These are the clue *patterns* — plain literals
    /// today, but matched through the regex engine so real patterns work later.
    private static func randomString(_ length: Int) -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }

    /// True if `pattern` (a regex) matches the entirety of `text`.
    private static func fullMatch(_ pattern: String, _ text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: text.utf16.count)
        guard let m = regex.firstMatch(in: text, range: range) else { return false }
        return m.range.location == 0 && m.range.length == text.utf16.count
    }

    /// One clue per perimeter edge among {0, 2, 4}. Mixed corners where two of
    /// these directions meet carry two clues, so every side is fully labeled.
    private static func assignClueEdges(_ perims: [PerimeterEdge]) -> [PerimeterEdge] {
        perims.filter { [0, 2, 4].contains($0.edge) }
    }

    private func handle(_ press: KeyPress, _ i: Int) -> KeyPress.Result {
        let delete = press.key == .delete || press.key == .deleteForward
            || press.characters == "\u{8}" || press.characters == "\u{7F}"
        if delete {
            if !letters[i].isEmpty { letters[i] = "" }
            else if i > 0 { letters[i - 1] = ""; focused = i - 1 }
            return .handled
        }
        if let ch = press.characters.first, ch.isLetter {
            letters[i] = String(ch.lowercased())
            focused = Swift.min(i + 1, order.count - 1)
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
