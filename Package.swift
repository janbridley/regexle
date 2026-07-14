// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "HexGrid",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "HexGridCore", targets: ["HexGridCore"]),
    .executable(name: "HexGridMac", targets: ["HexGridMac"]),
    .executable(name: "bench", targets: ["bench"]),
  ],
  targets: [
    .target(
      name: "HexGridCore",
      path: "Sources/HexGridCore"
    ),
    // Native macOS window app. Reuses the iOS app's view sources directly
    // (HexGridEntryView + ContentView); HexGridCore supplies the geometry.
    .executableTarget(
      name: "HexGridMac",
      dependencies: ["HexGridCore"],
      path: ".",
      sources: [
        "HexGrid/HexPuzzle.swift",
        "HexGrid/HexCursor.swift",
        "HexGrid/HexGridEntryView.swift",
        "HexGrid/ContentView.swift",
        "HexGrid/PuzzleStore.swift",
        "Sources/macApp",
      ]
    ),
    .executableTarget(
      name: "bench",
      dependencies: ["HexGridCore"],
      path: "Sources/bench"
    ),
    .testTarget(
      name: "HexGridCoreTests",
      dependencies: ["HexGridCore"],
      path: "Tests/HexGridCoreTests"
    ),
  ]
)
