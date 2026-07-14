//! End-to-end benchmark: puzzle generation and clue-matching time for n=2…8.
//!
//! Run:  swift run bench            (release: swift run -c release bench)
//! Prints a table + ASCII bar charts and writes bench_results.csv.
import Dispatch
import Foundation
import HexGridCore

private func now() -> Double {
    Double(DispatchTime.now().uptimeNanoseconds) / 1e9
}

/// The solve-check the store runs: every clue full-matches its solution line.
@inline(__always)
private func verify(_ topo: HexBoardTopology, _ clues: [String], _ solution: [String]) -> Bool {
    for i in 0..<clues.count {
        guard let line = topo.lineString(forClue: i, letters: solution) else { continue }
        if !RegexleGenerator.fullMatches(clues[i], line) { return false }
    }
    return true
}

struct Row {
    let n: Int
    let cells: Int
    let clues: Int
    let genMs: Double
    let matchMs: Double
}

private func bench(n: Int, genTrials: Int, matchTrials: Int) -> Row {
    let topo = HexBoardTopology(n: n)

    // Warm up caches (transform regexes, etc.).
    let warm = RegexleGenerator.generate(n: n, seed: 0)
    _ = verify(topo, warm.clues, warm.solution)

    // Generation: mean over several seeds.
    var genSec = 0.0
    for seed in 1...genTrials {
        let t = now()
        _ = RegexleGenerator.generate(n: n, seed: UInt64(seed))
        genSec += now() - t
    }
    let genMs = genSec / Double(genTrials) * 1000.0

    // Matching: mean over repeats on a fixed puzzle (isolates the check cost).
    let p = RegexleGenerator.generate(n: n, seed: 42)
    var matchSec = 0.0
    for _ in 0..<matchTrials {
        let t = now()
        _ = verify(topo, p.clues, p.solution)
        matchSec += now() - t
    }
    let matchMs = matchSec / Double(matchTrials) * 1000.0

    return Row(
        n: n, cells: topo.order.count, clues: topo.clueEdges.count,
        genMs: genMs, matchMs: matchMs)
}

// Scale trials down for large n so total runtime stays reasonable.
let rows = (2...8).map { (n: Int) -> Row in
    let genTrials = max(3, 48 / n)
    let matchTrials = max(20, 240 / n)
    return bench(n: n, genTrials: genTrials, matchTrials: matchTrials)
}

func pad(_ s: String, _ w: Int) -> String {
    s.count >= w ? s : s + String(repeating: " ", count: w - s.count)
}
print(pad("n", 4) + pad("cells", 8) + pad("clues", 8) + pad("gen(ms)", 12) + "match(ms)")
for r in rows {
    print(
        pad("\(r.n)", 4)
            + pad("\(r.cells)", 8)
            + pad("\(r.clues)", 8)
            + pad(String(format: "%.3f", r.genMs), 12)
            + String(format: "%.3f", r.matchMs))
}

func chart(_ title: String, _ values: [Double], _ labels: [String]) {
    print("\n" + title)
    let width = 32
    let maxV = values.max() ?? 1
    for (i, v) in values.enumerated() {
        let bars = maxV > 0 ? Int((v / maxV) * Double(width)) : 0
        let bar = String(repeating: "█", count: Swift.max(1, bars))
        print("  " + pad(labels[i], 6) + bar + " " + String(format: "%.3f", v))
    }
}
chart("Generation time (ms)", rows.map(\.genMs), rows.map { "n=\($0.n)" })
chart("Matching time (ms)", rows.map(\.matchMs), rows.map { "n=\($0.n)" })

var csv = "n,cells,clues,gen_ms,match_ms\n"
for r in rows {
    csv += "\(r.n),\(r.cells),\(r.clues),\(r.genMs),\(r.matchMs)\n"
}
try? csv.write(toFile: "bench_results.csv", atomically: true, encoding: .utf8)
print("\nWrote bench_results.csv")
