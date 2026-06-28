// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HexGrid",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "HexGridCore", targets: ["HexGridCore"]),
        .executable(name: "vis", targets: ["vis"]),
        .executable(name: "HexGridMac", targets: ["HexGridMac"]),
    ],
    targets: [
        .target(
            name: "HexGridCore",
            path: "Sources/HexGridCore"
        ),
        .executableTarget(
            name: "vis",
            dependencies: ["HexGridCore"],
            path: "Sources/vis"
        ),
        // Native macOS window app. Reuses the iOS app's view sources directly
        // (HexGridView + ContentView); HexGridCore supplies the geometry.
        .executableTarget(
            name: "HexGridMac",
            dependencies: ["HexGridCore"],
            path: ".",
            sources: [
                "HexGrid/HexGridView.swift",
                "HexGrid/ContentView.swift",
                "Sources/macApp",
            ]
        ),
        .testTarget(
            name: "HexGridCoreTests",
            dependencies: ["HexGridCore"],
            path: "Tests/HexGridCoreTests"
        ),
    ]
)
