import SwiftUI

import HexGridCore

#if os(iOS)
    import UIKit
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

    /// Which cell is active (the cursor). The single source of truth for the focus ring
    /// and cursor movement on every platform. It is a plain @State, NOT @FocusState, so
    /// on iOS nothing competes with the hidden text field for first responder.
    @State private var cursorIndex: Int?
    /// On macOS this mirrors `cursorIndex` into SwiftUI's focus system so hardware
    /// key events (`onKeyPress`) route to the active cell. Unused on iOS.
    @FocusState private var focused: Int?

    #if os(iOS)
    // Drives the hidden `UITextField` that captures software-keyboard input. `kbTick`
    // is bumped on each tap so the field (re)becomes first responder even after the user
    // dismisses the keyboard.
    @State private var kbActive = false
    @State private var kbTick = 0
    #endif

    init(n: Int, counter: Int, locked: Bool, initialLetters: [String],
         onNext: @escaping () -> Void, onLettersChange: @escaping ([String]) -> Void) {
        self.n = n
        self.onNext = onNext
        self.onLettersChange = onLettersChange
        _puzzle = State(initialValue: HexPuzzle(
            n: n, counter: counter, initialLetters: initialLetters, locked: locked))
        // A locked puzzle shows its border already drawn, with no animation — it starts
        // solved, so `.onChange` never fires and no popup appears.
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
            // A container View (not a ViewModifier) owns the zoom/pan @State, so its
            // identity is stable and the transform survives the GeometryReader re-layouts
            // that happen when the keyboard appears/disappears.
            ZoomableContainer(viewport: CGSize(width: CGFloat(w), height: CGFloat(h))) {
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
            }
            .scaleEffect(pulse ? 1.06 : 1.0)  // celebration pulse after the outline completes
        }
        .background {
            Color.white
            #if os(iOS)
            // Hidden text field parked offscreen: a real (hit-testable) first responder
            // so touch delivery to on-screen controls isn't disrupted, but 1×1 and off the
            // corner so it never overlaps a button/cell. It can still become first
            // responder and bring up the keyboard from offscreen.
            KeyboardCapture(active: $kbActive, tick: kbTick) { handleKeyboard($0) }
                .frame(width: 1, height: 1)
                .offset(x: -10_000, y: -10_000)
            #endif
        }
        .onAppear {
            if cursorIndex == nil { setCursor(0) }
            #if os(iOS)
            if !puzzle.locked { kbActive = true; kbTick += 1 }
            #endif
        }
        .onChange(of: puzzle.isFullySolved) { _, solved in
            if solved {
                #if os(iOS)
                kbActive = false  // dismiss the keyboard for the win overlay
                #endif
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

    /// Set the active cell. `cursorIndex` drives the ring on every platform; on macOS it
    /// also mirrors into `@FocusState` so `onKeyPress` receives hardware keys.
    private func setCursor(_ i: Int?) {
        cursorIndex = i
        #if os(macOS)
        focused = i
        #endif
    }

    private func outlines(grid: HexGrid, s: Double, origin: HexPoint) -> some View {
        Canvas { ctx, _ in
            var mates = Path()
            for i in puzzle.rowMates(of: cursorIndex) {
                mates.addPath(hexPath(puzzle.order[i], grid, origin))
            }
            ctx.fill(mates, with: .color(rowMateFill))
            var inactive = Path()
            var focusPath: Path?
            for (i, c) in puzzle.order.enumerated() {
                let hex = hexPath(c, grid, origin)
                if i == cursorIndex {
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
        // capped at the cell-letter size so clues never dwarf the grid. Raising
        // `clueClearance` trades smaller cells for larger text.
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
            onTap: {
                setCursor(cursor.didTap(i, in: puzzle))
                #if os(iOS)
                if !puzzle.locked, !puzzle.isFullySolved { kbActive = true; kbTick += 1 }
                #endif
            })
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

    // MARK: - Input

    /// Hardware-key handler (macOS only in practice — `.onKeyPress` is attached to cells
    /// only on macOS). Routes into the shared cell logic at cell `i`.
    private func handle(_ press: KeyPress, _ i: Int) -> KeyPress.Result {
        // Locked puzzles are immutable at the view layer (the store rejects writes for
        // non-active counters too).
        if puzzle.locked || puzzle.isFullySolved { return .ignored }
        let delete =
            press.key == .delete || press.key == .deleteForward
            || press.characters == "\u{8}" || press.characters == "\u{7F}"
        if delete {
            deleteLetter(at: i)
            return .handled
        }
        if let ch = press.characters.first, ch.isLetter {
            typeLetter(String(ch.uppercased()), at: i)
            return .handled
        }
        return .ignored
    }

    /// Shared by the hardware-key handler (`handle`, macOS) and the software-keyboard
    /// capture (iOS) so both input paths feed identical cell logic.
    private func typeLetter(_ ch: String, at i: Int) {
        guard !puzzle.locked, !puzzle.isFullySolved else { return }
        puzzle.letters[i] = ch
        setCursor(cursor.didType(i, in: puzzle))
        onLettersChange(puzzle.letters)
    }

    private func deleteLetter(at i: Int) {
        guard !puzzle.locked, !puzzle.isFullySolved else { return }
        if !puzzle.letters[i].isEmpty {
            puzzle.letters[i] = ""
        } else if let prev = cursor.backspaceTarget(from: i, in: puzzle) {
            puzzle.letters[prev] = ""
            setCursor(prev)
        }
        onLettersChange(puzzle.letters)
    }

    #if os(iOS)
    /// Software-keyboard entry: route each typed letter / backspace into the shared
    /// cell logic at the currently active cell.
    private func handleKeyboard(_ input: KeyboardCapture.Input) {
        guard !puzzle.locked, let i = cursorIndex else { return }
        switch input {
        case .letter(let ch): typeLetter(ch, at: i)
        case .delete: deleteLetter(at: i)
        }
    }
    #endif
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
        // Only one of these branches is compiled per platform, so `some View` stays
        // concrete. On iOS cells are plain `Text` — they hold no SwiftUI focus, so the
        // hidden text field's first responder is never stolen. macOS keeps
        // `.focusable`/`.onKeyPress` for hardware-key input.
        #if os(macOS)
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
        #else
        Text(letter)
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .frame(width: w, height: h)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .position(position)
        #endif
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

// MARK: - Native-style pinch-zoom + drag-pan

/// Pinch to zoom and drag to pan the board, the way UIScrollView does it: the zoom
/// anchors at the pinch midpoint (the content under your fingers stays put), the drag
/// flings with momentum and springs back within bounds, and cell taps stay instant.
///
/// This is a container `View` (not a `ViewModifier`) so its `@State` has a stable
/// structural identity and survives the parent `GeometryReader`'s re-layouts (e.g.
/// when the keyboard appears/disappears).
private struct ZoomableContainer<Content: View>: View {
    let viewport: CGSize
    var minZoom: CGFloat = 1
    var maxZoom: CGFloat = 3
    @ViewBuilder let content: () -> Content

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero

    // Gesture-start snapshots, captured on the first change of each gesture. The live
    // transform is committed to `@State` continuously during `.onChanged` (rather than
    // held in `@GestureState` and committed on `.onEnded`), so there is no transient
    // state to reset when the gesture ends — no "blip back" frame on release.
    @State private var dragStartPan: CGSize = .zero
    @State private var dragStarted = false
    @State private var pinchStartZoom: CGFloat = 1
    @State private var pinchStartPan: CGSize = .zero
    @State private var pinchStarted = false

    /// Keep the board from being dragged past the viewport edges at zoom `z`. At zoom 1
    /// the allowed range collapses to zero, so the board can't stray off-center.
    private func clamp(_ p: CGSize, for z: CGFloat) -> CGSize {
        let maxX = ((z - 1) * viewport.width) / 2
        let maxY = ((z - 1) * viewport.height) / 2
        return CGSize(
            width: Swift.min(maxX, Swift.max(-maxX, p.width)),
            height: Swift.min(maxY, Swift.max(-maxY, p.height)))
    }

    private func clampZoom(_ z: CGFloat) -> CGFloat {
        Swift.min(maxZoom, Swift.max(minZoom, z))
    }

    /// UnitPoint (0…1 in the view) → vector from the viewport center, in points.
    private func anchorVec(_ u: UnitPoint) -> CGSize {
        CGSize(width: (u.x - 0.5) * viewport.width, height: (u.y - 0.5) * viewport.height)
    }

    var body: some View {
        content()
            .scaleEffect(zoom, anchor: .center)
            .offset(pan)
            // Default-priority `.gesture` (not `.simultaneousGesture`): a simultaneous
            // gesture on this full-screen view was claiming taps meant for controls in
            // the parent view. With `.gesture`, a touch that moves pans/pinches and a
            // touch that doesn't reaches the cells (tap wins via the drag's 12px minimum).
            .gesture(dragGesture.simultaneously(with: pinchGesture))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if !dragStarted {
                    dragStarted = true
                    dragStartPan = pan
                }
                pan = clamp(dragStartPan + value.translation, for: zoom)
            }
            .onEnded { value in
                // Fling with the release velocity, then spring inside bounds.
                let target = dragStartPan + value.translation + value.velocity * 0.25
                dragStarted = false
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    pan = clamp(target, for: zoom)
                }
            }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if !pinchStarted {
                    pinchStarted = true
                    pinchStartZoom = zoom
                    pinchStartPan = pan
                }
                // Pinch-anchored: keep the midpoint fixed while scaling.
                let clamped = clampZoom(pinchStartZoom * value.magnification)
                let m = clamped / pinchStartZoom
                let a = anchorVec(value.startAnchor)
                zoom = clamped
                pan = clamp(pinchStartPan * m + a * (1 - m), for: clamped)
            }
            .onEnded { _ in
                pinchStarted = false
                // Committed zoom/pan already hold the final clamped value (updated
                // continuously during the gesture), so nothing to animate on release.
            }
    }
}

private func + (lhs: CGSize, rhs: CGSize) -> CGSize {
    CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
}

private func * (vector: CGSize, scalar: CGFloat) -> CGSize {
    CGSize(width: vector.width * scalar, height: vector.height * scalar)
}

// MARK: - Software-keyboard capture (iOS)

#if os(iOS)
/// An invisible `UITextField` whose delegate reports each typed letter and each
/// backspace — the only reliable way to read the on-screen keyboard (a SwiftUI
/// `TextField`'s `onChange` can't tell a real backspace apart from a programmatic clear).
/// It never stores text; every edit is rejected after being reported.
private struct KeyboardCapture: UIViewRepresentable {
    @Binding var active: Bool
    let tick: Int
    let onInput: (Input) -> Void

    enum Input {
        case letter(String)
        case delete
    }

    func makeUIView(context: Context) -> CaptureField {
        let f = CaptureField()
        f.onInput = onInput
        f.delegate = f
        f.autocorrectionType = .no
        f.autocapitalizationType = .allCharacters
        f.spellCheckingType = .no
        f.smartDashesType = .no
        f.smartQuotesType = .no
        f.smartInsertDeleteType = .no
        f.keyboardType = .asciiCapable
        f.alpha = 0.01
        return f
    }

    func updateUIView(_ f: CaptureField, context: Context) {
        f.onInput = onInput
        if !active, f.isFirstResponder {
            f.resignFirstResponder()
        } else if active, f.lastTick != tick {
            f.lastTick = tick
            f.becomeFirstResponder()
        } else if active, !f.isFirstResponder {
            f.becomeFirstResponder()
        }
    }
}

private final class CaptureField: UITextField, UITextFieldDelegate {
    var onInput: ((KeyboardCapture.Input) -> Void)?
    var lastTick = 0

    override var canBecomeFirstResponder: Bool { true }

    func textField(_ tf: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        if string.isEmpty {
            onInput?(.delete)  // backspace
        } else if let ch = string.first, ch.isLetter {
            onInput?(.letter(String(ch).uppercased()))
        }
        return false  // never accumulate text
    }
}
#endif
