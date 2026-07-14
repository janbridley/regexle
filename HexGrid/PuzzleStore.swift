import Foundation
import HexGridCore

/// Persisted puzzle progress (local only — no server). Clues regenerate from `(n, counter)`
/// via the RNG, so only the user's per-puzzle solution text is stored. Each solution is a
/// compact ASCII string (one char per cell; `" "` = empty), tens of bytes for typical
/// board sizes, so the whole store stays in the kilobyte range.
struct ProgressV1: Codable {
  var defaultN: Int = 4
  /// n → user solution strings; index `i` is counter `i+1`. With no "skip", the solved
  /// range per size is the contiguous prefix `1…solutions[n].count`, so an array suffices.
  var solutions: [Int: [String]] = [:]
  /// n → in-progress letters for the active (next unsolved) counter.
  var active: [Int: String] = [:]
}

/// Source of truth for the puzzle history: the solved count per size, the currently-viewed
/// counter, and the in-progress typing of the active puzzle. Backed by `ProgressV1` in
/// `UserDefaults`. `@MainActor` because it is UI-owned.
@MainActor
final class PuzzleStore: ObservableObject {

  @Published private(set) var n: Int
  @Published private(set) var viewedCounter: Int
  @Published private(set) var progress: ProgressV1

  private static let defaultsKey = "regexle.progress.v1"

  init() {
    let loaded = Self.load()
    var p = loaded
    // Self-heal: if the active puzzle's stored letters already solve it (e.g. the app
    // was closed after solving but before tapping "Next"), record it now so relaunch
    // shows the next empty puzzle instead of a surprise "You Win!" popup.
    if let activeStr = p.active[loaded.defaultN],
      Self.solvesActive(in: p, n: loaded.defaultN, lettersString: activeStr)
    {
      p.solutions[loaded.defaultN, default: []].append(activeStr)
      p.active[loaded.defaultN] = nil
    }
    self.progress = p
    self.n = p.defaultN
    // Open on the latest unsolved puzzle of the default size.
    self.viewedCounter = Self.activeCounter(of: p, n: p.defaultN)
    persist()
  }

  // MARK: - Derived (current size)

  var solvedCount: Int { Self.solvedCount(in: progress, n: n) }
  var activeCounter: Int { Self.activeCounter(of: progress, n: n) }
  /// A viewed counter below the active one is a locked, already-solved puzzle.
  var viewedIsSolved: Bool { viewedCounter < activeCounter }

  // MARK: - Navigation

  func goPrev() { viewedCounter = max(1, viewedCounter - 1) }
  func goNext() { viewedCounter = min(activeCounter, viewedCounter + 1) }

  func setN(_ newN: Int) {
    guard newN != n, (1...8).contains(newN) else { return }
    n = newN
    progress.defaultN = newN
    viewedCounter = activeCounter
    persist()
  }

  // MARK: - Letters

  /// Stored letters for `(n, counter)`: the user's solution for a solved counter, the
  /// in-progress typing for the active counter, empty otherwise.
  func letters(for n: Int, counter: Int) -> [String] {
    let count = HexBoardTopology(n: n).order.count
    let solved = Self.solvedCount(in: progress, n: n)
    if counter >= 1 && counter <= solved, let sols = progress.solutions[n] {
      return Self.decode(sols[counter - 1], count: count)
    }
    if counter == Self.activeCounter(of: progress, n: n), let s = progress.active[n] {
      return Self.decode(s, count: count)
    }
    return []
  }

  /// Record the active puzzle's current typing. Writes the active counter only — solved
  /// puzzles are immutable from the store side too (defense in depth alongside the view
  /// lock).
  func setLetters(_ letters: [String], forActiveOf n: Int) {
    guard n == self.n, viewedCounter == activeCounter else { return }
    progress.active[n] = Self.encode(letters)
    persist()
  }

  /// Commit the active puzzle as solved: append the user's solution, clear the active
  /// typing, advance to the next unsolved puzzle. No-op if the active letters don't
  /// actually solve the puzzle (mirrors `HexPuzzle.isFullySolved`).
  func markSolved() {
    guard let lettersStr = progress.active[n],
      Self.solvesActive(in: progress, n: n, lettersString: lettersStr)
    else { return }
    progress.solutions[n, default: []].append(lettersStr)
    progress.active[n] = nil
    persist()
    viewedCounter = activeCounter
  }

  // MARK: - Encoding (one ASCII char per cell; " " = empty)

  static func encode(_ letters: [String]) -> String {
    letters.map { $0.isEmpty ? " " : $0 }.joined()
  }

  static func decode(_ s: String, count: Int) -> [String] {
    var out = Array(s).map { $0 == " " ? "" : String($0) }
    while out.count < count { out.append("") }
    return Array(out.prefix(count))
  }

  // MARK: - Persistence

  private func persist() {
    guard let data = try? JSONEncoder().encode(progress) else { return }
    UserDefaults.standard.set(data, forKey: Self.defaultsKey)
  }

  private static func load() -> ProgressV1 {
    guard let data = UserDefaults.standard.data(forKey: defaultsKey),
      let decoded = try? JSONDecoder().decode(ProgressV1.self, from: data)
    else { return ProgressV1() }
    return decoded
  }

  // MARK: - Pure helpers (operate on a value, no actor state)

  private static func solvedCount(in p: ProgressV1, n: Int) -> Int { p.solutions[n]?.count ?? 0 }
  private static func activeCounter(of p: ProgressV1, n: Int) -> Int {
    solvedCount(in: p, n: n) + 1
  }

  /// True when `lettersString` fully solves the active puzzle of size `n`: every cell
  /// filled and every clue full-matches its line.
  private static func solvesActive(in p: ProgressV1, n: Int, lettersString: String) -> Bool {
    let topo = HexBoardTopology(n: n)
    let generated = RegexleGenerator.generate(
      n: n, seed: UInt64(activeCounter(of: p, n: n)), secondSeed: UInt64(n))
    let letters = decode(lettersString, count: topo.order.count)
    guard letters.allSatisfy({ !$0.isEmpty }) else { return false }
    for i in 0..<generated.clues.count {
      guard let line = topo.lineString(forClue: i, letters: letters) else { return false }
      let cells = topo.grid.rowCells(for: topo.clueEdges[i])
      guard line.count == cells.count,
        RegexleGenerator.fullMatches(generated.clues[i], line)
      else { return false }
    }
    return true
  }
}
