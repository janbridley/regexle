import CoreGraphics
import Foundation
import HexGridCore
import ImageIO
import UniformTypeIdentifiers

func value(for flag: String, fallback: String) -> String {
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: flag), i + 1 < a.count { return a[i + 1] }
    return fallback
}
func die(_ m: String) -> Never {
    FileHandle.standardError.write("\(m)\n".data(using: .utf8)!)
    exit(1)
}

let n = Int(value(for: "--n", fallback: "4")) ?? 4
let px = Int(value(for: "--size", fallback: "800")) ?? 800
let scale = Double(value(for: "--scale", fallback: "2")) ?? 2
let outArg = value(for: "--out", fallback: "out/grid.png")

let W = CGFloat(px)
let H = CGFloat(px)
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard
    let ctx = CGContext(
        data: nil, width: Int(W * scale), height: Int(H * scale),
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { die("no context") }

ctx.scaleBy(x: scale, y: scale)
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
ctx.translateBy(x: 0, y: H)
ctx.scaleBy(x: 1, y: -1)  // flip to top-left origin

let s = CGFloat(HexGrid.radiusFitting(n: n, width: Double(W), height: Double(H)))
let grid = HexGrid(n: n, radius: Double(s))
ctx.setStrokeColor(CGColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1))
ctx.setLineWidth(max(0.5, s * 0.018))
ctx.setLineJoin(.round)
ctx.setLineCap(.round)

for hex in grid.hexagons(inWidth: Double(W), height: Double(H)) {
    ctx.beginPath()
    for (i, p) in hex.enumerated() {
        let pt = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        if i == 0 { ctx.move(to: pt) } else { ctx.addLine(to: pt) }
    }
    ctx.closePath()
    ctx.strokePath()
}

guard let img = ctx.makeImage() else { die("no image") }
let url = URL(fileURLWithPath: outArg)
try? FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
guard
    let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
else { die("no dest") }
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { die("write failed") }
print("wrote \(url.path)  (\(n)×\(n), \(Int(W * scale))×\(Int(H * scale)) px)")
