import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore  // macOS executable: core is a package dependency
#endif

/// An interactive hexagonal cluster where each cell is a single-letter text
/// field. Typing one letter stores it and advances focus to the next cell in
/// reading order (left-to-right, wrapping to the next row), exactly like
/// filling in a crossword.
///
/// The hex outlines are stroked on a `Canvas` (line art); one small `TextField`
/// is positioned at each cell center. Focus is driven by a single
/// `@FocusState<Int?>`, and the active cell's outline is highlighted.
struct HexGridEntryView: View {

    let n: Int

    @State private var letters: [String]
    @FocusState private var focused: Int?

    init(n: Int) {
        self.n = n
        let count = HexGrid(n: n, radius: 1).cellCount
        _letters = State(initialValue: Array(repeating: "", count: count))
    }

    /// Cells in traversal (row-major) order — drives both layout and advance.
    private var order: [(q: Int, r: Int)] { HexGrid(n: n, radius: 1).cells() }

    var body: some View {
        GeometryReader { proxy in
            let w = Double(proxy.size.width)
            let h = Double(proxy.size.height)
            let s = HexGrid.radiusFitting(n: n, width: w, height: h)
            let grid = HexGrid(n: n, radius: s)
            let cellW = HexGrid.sqrt3 * s * 0.92
            let cellH = 1.7 * s

            ZStack {
                // Hex outlines (line art); the active cell is highlighted.
                Canvas { context, _ in
                    var inactive = Path()
                    let activeColor = Color.accentColor
                    let baseColor = Color(red: 0.6, green: 0.6, blue: 0.6)
                    for (i, cell) in order.enumerated() {
                        let hex = path(for: cell, in: grid, originX: w / 2, originY: h / 2)
                        if i == focused {
                            context.stroke(
                                hex,
                                with: .color(activeColor),
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

                // One single-letter field per cell, centered on its hexagon.
                ForEach(0..<order.count, id: \.self) { i in
                    let cell = order[i]
                    let c = grid.center(q: cell.q, r: cell.r, originX: w / 2, originY: h / 2)
                    TextField("", text: letterBinding(at: i))
                        .focused($focused, equals: i)
                        .multilineTextAlignment(.center)
                        .font(.system(size: CGFloat(s * 0.8), weight: .medium, design: .rounded))
                        #if os(macOS)
                        .textFieldStyle(.plain)
                        #endif
                        .frame(width: CGFloat(cellW), height: CGFloat(cellH))
                        .position(x: CGFloat(c.x), y: CGFloat(c.y))
                }
            }
        }
        .background(Color.white)
        .onAppear { if focused == nil { focused = 0 } }
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

    /// Binding that enforces a single uppercase letter and advances focus.
    private func letterBinding(at i: Int) -> Binding<String> {
        Binding(
            get: { letters[i] },
            set: { newValue in
                let cleaned = newValue.uppercased().filter(\.isLetter)
                if let last = cleaned.last {
                    letters[i] = String(last)
                    focused = (i + 1 < order.count) ? i + 1 : nil   // advance; clear at the end
                } else if newValue.isEmpty {
                    letters[i] = ""                                  // backspace clears, no advance
                }
            }
        )
    }
}
