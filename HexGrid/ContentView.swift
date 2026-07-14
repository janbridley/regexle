import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore  // macOS executable: core is a package dependency
#endif

struct ContentView: View {
    @State private var n: Int = 4
    @State private var seed: UInt64 = .random(in: 0..<UInt64.max)

    private func newPuzzle() {
        seed = .random(in: 0..<UInt64.max)
    }

    var body: some View {
        VStack(spacing: 16) {
            // `.id("\(n)-\(seed)")` rebuilds the entry grid when either changes.
            HexGridEntryView(n: n, seed: seed)
                .id("\(n)-\(seed)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("New puzzle") { newPuzzle() }
                    .buttonStyle(.bordered)
                Spacer()
                Stepper(
                    "Side: \(n)  (\(HexGrid(n: n, radius: 1).cellCount) cells)", value: $n, in: 1...8
                )
                .onChange(of: n) { _, _ in newPuzzle() }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.white)
    }
}

#Preview {
    ContentView()
}
