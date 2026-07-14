import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore  // macOS executable: core is a package dependency
#endif

struct ContentView: View {
    @StateObject private var store = PuzzleStore()

    var body: some View {
        ZStack(alignment: .topLeading) {
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

            historyControls
                .padding(.horizontal)
                .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            sizeBar
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .background(Color.white)
    }

    /// Top-left ‹ / › controls to browse solved puzzles (and return to the active one).
    /// The right arrow is clamped at the active counter — there is nothing beyond it
    /// (no skip); forward motion happens only by solving.
    private var historyControls: some View {
        HStack(spacing: 6) {
            Button { store.goPrev() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(store.viewedCounter <= 1)

            Text("\(store.viewedCounter) / \(store.activeCounter)")
                .monospacedDigit()
                .frame(minWidth: 44)

            Button { store.goNext() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(store.viewedCounter >= store.activeCounter)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(store.viewedIsSolved ? solvedColor : .primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.white.opacity(0.85), in: Capsule())
        .overlay(Capsule().stroke(.gray.opacity(0.3)))
    }

    private var sizeBar: some View {
        HStack {
            Spacer()
            Stepper(
                "Side: \(store.n)  (\(HexGrid(n: store.n, radius: 1).cellCount) cells)"
            ) {
                store.setN(min(8, store.n + 1))
            } onDecrement: {
                store.setN(max(1, store.n - 1))
            }
        }
    }
}

#Preview {
    ContentView()
}
