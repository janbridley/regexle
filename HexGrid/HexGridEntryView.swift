import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore
#endif

/// Single-letter entry grid with clue strings on the left (edge 2, horizontal)
/// and upper-left (edge 3) perimeter edges. Type to advance, Backspace to step back.
struct HexGridEntryView: View {

    let n: Int
    @State private var letters: [String]
    @State private var clues: [String]
    @FocusState private var focused: Int?

    init(n: Int) {
        self.n = n
        let g = HexGrid(n: n, radius: 1)
        _letters = State(initialValue: Array(repeating: "", count: g.cellCount))
        _clues = State(initialValue: g.perimeterEdges()
            .filter { $0.edge == 2 || $0.edge == 4 }
            .map { Self.randomString(g.rowLength(of: $0)) })
    }

    private var order: [(q: Int, r: Int)] { HexGrid(n: n, radius: 1).cells() }

    var body: some View {
        GeometryReader { p in
            let w = Double(p.size.width), h = Double(p.size.height)
            let s = HexGrid.radiusFitting(n: n, width: w, height: h)
            let grid = HexGrid(n: n, radius: s)
            ZStack {
                outlines(grid, w, h, s)
                labels(grid, w, h, s)
                ForEach(0..<order.count, id: \.self) { cell($0, grid, w, h, s) }
            }
        }
        .background(Color.white)
        .onAppear { if focused == nil { focused = 0 } }
    }

    private func outlines(_ grid: HexGrid, _ w: Double, _ h: Double, _ s: Double) -> some View {
        Canvas { ctx, _ in
            var inactive = Path()
            for (i, c) in order.enumerated() {
                let hex = hexPath(c, grid, w / 2, h / 2)
                if i == focused {
                    ctx.stroke(hex, with: .color(.accentColor),
                               style: StrokeStyle(lineWidth: max(1.5, s * 0.04), lineCap: .round, lineJoin: .round))
                } else { inactive.addPath(hex) }
            }
            ctx.stroke(inactive, with: .color(Color(red: 0.6, green: 0.6, blue: 0.6)),
                       style: StrokeStyle(lineWidth: max(0.5, s * 0.018), lineCap: .round, lineJoin: .round))
        }
    }

    /// N-char clue strings on the left (edge 2, horizontal) and upper-right
    /// (edge 4) edges, each offset outward along its normal and tilted to match.
    private func labels(_ grid: HexGrid, _ w: Double, _ h: Double, _ s: Double) -> some View {
        let edges = grid.perimeterEdges(originX: w / 2, originY: h / 2)
            .filter { $0.edge == 2 || $0.edge == 4 }
        let off = s * 0.7
        return ForEach(Array(edges.enumerated()), id: \.offset) { idx, e in
            ClueLabel(
                text: idx < clues.count ? clues[idx] : "",
                size: CGFloat(s * 0.3),
                position: CGPoint(x: CGFloat(e.midpoint.x + e.outward.x * off),
                                  y: CGFloat(e.midpoint.y + e.outward.y * off)),
                rotation: Self.baselineAngle(e.outward))
        }
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

    private static func randomString(_ length: Int) -> String {
        let a = Array("abcdefghijklmnopqrstuvwxyz")
        return String((0..<length).map { _ in a.randomElement()! })
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
            .focusable()
            .focusEffectDisabled()
            .focused(focus, equals: index)
            .onKeyPress(action: onKey)
            .position(position)
    }
}

private struct ClueLabel: View {
    let text: String
    let size: CGFloat
    let position: CGPoint
    let rotation: Double

    var body: some View {
        Text(text)
            .font(.system(size: size, design: .monospaced))
            .foregroundStyle(.red)
            .rotationEffect(.degrees(rotation))
            .position(position)
    }
}
