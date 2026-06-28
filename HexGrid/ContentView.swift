import SwiftUI

#if canImport(HexGridCore)
    import HexGridCore  // macOS executable: core is a package dependency
#endif

struct ContentView: View {
    @State private var n: Int = 4

    var body: some View {
        VStack(spacing: 16) {
            // `.id(n)` rebuilds the entry grid when n changes, resizing storage.
            HexGridEntryView(n: n)
                .id(n)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Stepper("Side: \(n)  (\(HexGrid(n: n, radius: 1).cellCount) cells)", value: $n, in: 1...8)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .background(Color.white)
    }
}

#Preview {
    ContentView()
}
