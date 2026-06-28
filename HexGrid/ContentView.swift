import SwiftUI
#if canImport(HexGridCore)
import HexGridCore          // macOS executable: core is a package dependency
#endif

struct ContentView: View {
    @State private var n: Int = 4

    var body: some View {
        VStack(spacing: 16) {
            HexGridView(n: n)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Stepper("Grid: \(n) × \(n)", value: $n, in: 1...20)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .background(Color.white)
    }
}

#Preview {
    ContentView()
}
