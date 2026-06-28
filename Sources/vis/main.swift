import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import HexGridCore

// Parse CLI args: --n <int> --size <px> --scale <float> --out <path>
func value(for flag: String, fallback: String) -> String {
    let args = ProcessInfo.processInfo.arguments
    if let i = args.firstIndex(of: flag), i + 1 < args.count {
        return args[i + 1]
    }
    return fallback
}

let n      = Int(value(for: "--n",    fallback: "4"))     ?? 4
let size   = Int(value(for: "--size", fallback: "800"))   ?? 800
let scale  = Double(value(for: "--scale", fallback: "2")) ?? 2
let outArg = value(for: "--out",   fallback: "out/grid.png")

// CoreGraphics speaks CGFloat; keep all CG math in CGFloat and convert the
// Double-based geometry at the boundary.
let width  = CGFloat(size)
let height = CGFloat(size)
let canvasW = width * CGFloat(scale)
let canvasH = height * CGFloat(scale)

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil,
    width:  Int(canvasW),
    height: Int(canvasH),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write("error: could not create bitmap context\n".data(using: .utf8)!)
    exit(1)
}

// Work in points; scale up for crispness (vector → sharp at any scale).
ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

// White background.
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

// CGContext origin is bottom-left, y-up; our geometry is top-left, y-down.
// Flip so the rendered orientation matches what the iOS view shows.
ctx.translateBy(x: 0, y: height)
ctx.scaleBy(x: 1, y: -1)

let radius = CGFloat(HexGrid.radiusFitting(n: n, width: Double(width), height: Double(height)))
let grid = HexGrid(n: n, radius: Double(radius))

ctx.setStrokeColor(CGColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1))
ctx.setLineWidth(max(0.5, radius * 0.018))
ctx.setLineJoin(.round)
ctx.setLineCap(.round)

for hex in grid.hexagons(inWidth: Double(width), height: Double(height)) {
    ctx.beginPath()
    for (i, p) in hex.enumerated() {
        let point = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        if i == 0 { ctx.move(to: point) }
        else      { ctx.addLine(to: point) }
    }
    ctx.closePath()
    ctx.strokePath()
}

guard let image = ctx.makeImage() else {
    FileHandle.standardError.write("error: could not render image\n".data(using: .utf8)!)
    exit(1)
}

let outURL = URL(fileURLWithPath: outArg)
try? FileManager.default.createDirectory(
    at: outURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let destination = CGImageDestinationCreateWithURL(
    outURL as CFURL, UTType.png.identifier as CFString, 1, nil
) else {
    FileHandle.standardError.write("error: could not create image file\n".data(using: .utf8)!)
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write("error: could not write PNG\n".data(using: .utf8)!)
    exit(1)
}

print("wrote \(outURL.path)  (\(n)×\(n), \(Int(canvasW))×\(Int(canvasH)) px)")
