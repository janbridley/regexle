import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore  // macOS executable: core is a package dependency
#endif

struct ContentView: View {
    @StateObject private var store = PuzzleStore()

    var body: some View {
        HexGridEntryView(
            n: store.n,
            counter: store.viewedCounter,
            locked: store.viewedIsSolved,
            initialLetters: store.letters(for: store.n, counter: store.viewedCounter),
            onNext: { store.markSolved() },
            onLettersChange: { store.setLetters($0, forActiveOf: store.n) }
        )
        // Rebuild when either the size or the viewed counter changes: each (n, counter)
        // is a distinct puzzle with its own locked/letters state.
        .id("\(store.n)-\(store.viewedCounter)")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Controls live in a top bar so they're never covered by the keyboard (which
        // rises from the bottom) and are easy to reach.
        .overlay(alignment: .top) {
            chrome
                .padding(.horizontal, 12)
                .padding(.top, 10)
        }
        .background(Color.white)
    }

    /// Top control bar: puzzle history on the left, board-size on the right.
    private var chrome: some View {
        HStack(spacing: 16) {
            historyControls
            Spacer()
            sizeControls
        }
    }

    /// ‹  counter / total  ›  to browse solved puzzles. `‹` is disabled on the first
    /// puzzle; `›` is disabled on the active (latest) one — there's nothing past it.
    private var historyControls: some View {
        let atStart = store.viewedCounter <= 1
        let atEnd = store.viewedCounter >= store.activeCounter
        return HStack(spacing: 4) {
            chromeButton(systemName: "chevron.left", disabled: atStart) { store.goPrev() }
            Text("\(store.viewedCounter) / \(store.activeCounter)")
                .monospacedDigit()
                .frame(minWidth: 56)
                .foregroundStyle(store.viewedIsSolved ? solvedColor : .primary)
            chromeButton(systemName: "chevron.right", disabled: atEnd) { store.goNext() }
        }
    }

    /// −  size N  +  to change the board size (1…8).
    private var sizeControls: some View {
        let atMin = store.n <= 1
        let atMax = store.n >= 8
        return HStack(spacing: 4) {
            chromeButton(systemName: "minus", disabled: atMin) { store.setN(max(1, store.n - 1)) }
            Text("\(store.n)")
                .monospacedDigit()
                .frame(minWidth: 40)
                .foregroundStyle(.primary)
            chromeButton(systemName: "plus", disabled: atMax) { store.setN(min(8, store.n + 1)) }
        }
    }

    /// A 44×44 control button (SF Symbol label) with a clear press + disabled state.
    @ViewBuilder
    private func chromeButton(systemName: String, disabled: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(.chrome)
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
    }
}

// MARK: - Chrome button style

/// 44×44 rounded control button (HIG minimum tap target) with press feedback. SwiftUI
/// doesn't expose `isEnabled` inside `ButtonStyle`, so the disabled dimming is applied
/// at the call site via `.opacity()`.
struct ChromeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.gray.opacity(configuration.isPressed ? 0.28 : 0.12))
            )
    }
}

extension ButtonStyle where Self == ChromeButtonStyle {
    static var chrome: ChromeButtonStyle { ChromeButtonStyle() }
}

#Preview {
    ContentView()
}
