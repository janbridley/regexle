//! This code is ported from Nathaniel Belle's `regexle_generator gitlab`, with
//! adaptions made to improve performance and function within Swift. See the reference
//! implementation at https://gitlab.com/Nathaniel.Belles/regexle_generator
import Foundation

/// One generated puzzle: `clues` is parallel to `HexBoardTopology.clueEdges`, and
/// `solution` is parallel to `HexBoardTopology.order` (one uppercase letter per cell).
public struct GeneratedPuzzle: Equatable {
    public let n: Int
    public let seed: UInt64
    public let clues: [String]
    public let solution: [String]

    public init(n: Int, seed: UInt64, clues: [String], solution: [String]) {
        self.n = n
        self.seed = seed
        self.clues = clues
        self.solution = solution
    }
}

/// Generates solvable hex regex-crossword puzzles by the regexle.com method:
/// fill the grid with random letters, then derive a regex per line from the line's
/// solution string, verifying each clue **full-matches** its line. Deterministic for a
/// given `(n, seed, difficulty)`.
public enum RegexleGenerator {

    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    /// Strict full-string match using the same engine the UI checker uses.
    /// Returns false on either a compile error or a non-full match, so callers can
    /// treat "bad clue" uniformly and retry.
    public static func fullMatches(_ pattern: String, _ text: String) -> Bool {
        guard let regex = try? Regex(pattern) else { return false }
        return (try? regex.wholeMatch(in: text)) != nil
    }

    /// Generate a solvable puzzle. Postcondition (the parity invariant): for every
    /// clue `i`, `fullMatches(clues[i], topology.lineString(forClue: i, letters: solution))`.
    public static func generate(
        n: Int,
        seed: UInt64,
        difficulty: Double = 0.5,
        maxAttemptsPerClue: Int = 64
    ) -> GeneratedPuzzle {
        precondition(n >= 1, "n must be ≥ 1")
        var rng = SFC64(seed: seed)
        let topo = HexBoardTopology(n: n)

        // Fill every cell with a random uppercase letter (the solution).
        var solution: [String] = []
        solution.reserveCapacity(topo.order.count)
        for _ in topo.order {
            solution.append(randomChar(using: &rng))
        }

        // One verified clue per line, read in the same order the checker reads.
        var clues: [String] = []
        clues.reserveCapacity(topo.clueEdges.count)
        for i in 0..<topo.clueEdges.count {
            let fullStr = topo.lineString(forClue: i, letters: solution) ?? ""
            clues.append(makeClue(for: fullStr, difficulty: difficulty,
                                  maxAttempts: maxAttemptsPerClue, using: &rng))
        }
        return GeneratedPuzzle(n: n, seed: seed, clues: clues, solution: solution)
    }

    // MARK: - Per-clue generation

    /// Build a clue that full-matches `fullStr`. Tries randomized candidates up to
    /// `maxAttempts`, rejecting any that don't compile, don't full-match, or exceed
    /// the length budget (so clues fit the view). Falls back to simple short patterns
    /// when the system is stuck in some overconstrained state.
    private static func makeClue(for fullStr: String, difficulty: Double,
                                 maxAttempts: Int, using rng: inout SFC64) -> String {
        let len = fullStr.count
        if len == 0 { return ".*" }
        let budget = max(8, 2 * len + 8)
        for _ in 0..<maxAttempts {
            let candidate = randomRegex(for: fullStr, difficulty: difficulty, using: &rng)
            if candidate.count <= budget && fullMatches(candidate, fullStr) {
                return candidate
            }
        }
        // Guaranteed fallback: `.*<char>.*` full-matches since the char is in the line.
        let chars = Array(fullStr)
        let fallback = ".*\(chars[len / 2]).*"
        if fullMatches(fallback, fullStr) { return fallback }
        return ".*"
    }

    /// One randomized regex for `fullStr`, built from a random template + substrings,
    /// then post-processed by the regexle transforms.
    private static func randomRegex(for fullStr: String, difficulty: Double,
                                    using rng: inout SFC64) -> String {
        let chars = Array(fullStr)
        let len = chars.count
        let matchLength = max(1, min(len, Int((Double(len) * difficulty).rounded(.up))))
        let position = Int.random(in: 0...(len - matchLength), using: &rng)
        let center = String(chars[position..<(position + matchLength)])
        var beforeStr = String(chars[0..<position])
        let beforeSubstr = randomSubstring(of: beforeStr, using: &rng)
        var afterStr = String(chars[(position + matchLength)..<len])
        let afterSubstr = randomSubstring(of: afterStr, using: &rng)

        // regexle replaces empty before/after with a random char so the alternation
        // templates never get an empty branch.
        if beforeStr.isEmpty { beforeStr = randomChar(using: &rng) }
        if afterStr.isEmpty { afterStr = randomChar(using: &rng) }

        let distractor = noRepetitionRandomString(
            avoiding: [center, afterStr, beforeStr, beforeSubstr, afterSubstr, fullStr],
            maxLen: max(1, len - 1), using: &rng)

        let template = templates[Int.random(in: 0..<templates.count, using: &rng)]
        var rule = format(template, distractor: distractor, center: center,
                          beforeStr: beforeStr, afterStr: afterStr,
                          beforeSubstr: beforeSubstr, afterSubstr: afterSubstr,
                          fullStr: fullStr)
        rule = applyTransforms(rule)
        return rule
    }

    // MARK: - Random pieces (all draws go through `rng` for determinism)

    private static func randomChar(using rng: inout SFC64) -> String {
        String(alphabet[Int.random(in: 0..<alphabet.count, using: &rng)])
    }

    /// Random contiguous slice of `s`, possibly empty (mirrors regexle's
    /// `random_substring`); returns "" for empty input.
    private static func randomSubstring(of s: String, using rng: inout SFC64) -> String {
        guard !s.isEmpty else { return s }
        let chars = Array(s)
        let lower = Int.random(in: 0..<chars.count, using: &rng)
        let upper = Int.random(in: lower...chars.count, using: &rng)
        return String(chars[lower..<upper])
    }

    /// A random 1…`maxLen` char string not equal to any entry in `avoiding`.
    private static func noRepetitionRandomString(avoiding: [String], maxLen: Int,
                                                 using rng: inout SFC64) -> String {
        let avoid = Set(avoiding)
        let length = Int.random(in: 1...max(1, maxLen), using: &rng)
        while true {
            let s = String((0..<length).map { _ in
                alphabet[Int.random(in: 0..<alphabet.count, using: &rng)]
            })
            if !avoid.contains(s) { return s }
        }
    }

    /// Fill a template's named/positional holes. `{}` is the distractor.
    private static func format(_ template: String, distractor: String, center: String,
                               beforeStr: String, afterStr: String,
                               beforeSubstr: String, afterSubstr: String,
                               fullStr: String) -> String {
        var s = template
        s = s.replacingOccurrences(of: "{before_substr}", with: beforeSubstr)
        s = s.replacingOccurrences(of: "{after_substr}", with: afterSubstr)
        s = s.replacingOccurrences(of: "{before_str}", with: beforeStr)
        s = s.replacingOccurrences(of: "{after_str}", with: afterStr)
        s = s.replacingOccurrences(of: "{center}", with: center)
        s = s.replacingOccurrences(of: "{full_str}", with: fullStr)
        s = s.replacingOccurrences(of: "{}", with: distractor)
        return s
    }

    // MARK: - Transforms (faithful port of regexle's RegexGenerator via ICU regex)

    private static func applyTransforms(_ rule: String) -> String {
        var s = rule
        s = middleQuestion(s)
        s = endQuestion(s)
        s = addBrackets(s)
        s = removeDuplicateChars(s)
        s = removeDoubleAsterisks(s)
        return s
    }

    /// Replace only the first match of `pattern` (Python `re.sub(..., count=1)`).
    private static func subFirst(_ pattern: String, _ input: String, _ template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let full = NSRange(location: 0, length: input.utf16.count)
        guard let m = regex.firstMatch(in: input, range: full) else { return input }
        let mutable = NSMutableString(string: input)
        regex.replaceMatches(in: mutable, range: m.range, withTemplate: template)
        return mutable as String
    }

    /// Replace every match of `pattern` (Python `re.sub`).
    private static func subAll(_ pattern: String, _ input: String, _ template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let mutable = NSMutableString(string: input)
        let full = NSRange(location: 0, length: input.utf16.count)
        regex.replaceMatches(in: mutable, range: full, withTemplate: template)
        return mutable as String
    }

    /// `MY|.*|Y`, `MY|Y`, `Y|.*|MY`, `Y|MY` → `M?Y|.*` / `M?Y`.
    static func middleQuestion(_ r: String) -> String {
        var s = r
        s = subFirst("([|(])([A-Za-z])([A-Za-z])\\|(.*)\\|\\3([|)])", s, "$1$2?$3|$4$5")
        s = subFirst("([|(])([A-Za-z])([A-Za-z])\\|\\3([|)])", s, "$1$2?$3$4")
        s = subFirst("([|(])([A-Za-z])\\|(.*)\\|([A-Za-z])\\2([|)])", s, "$1$4?$2|$3$5")
        s = subFirst("([|(])([A-Za-z])\\|([A-Za-z])\\2([|)])", s, "$1$3?$2$4")
        return s
    }

    /// `PM|.*|P`, `PM|P`, `P|.*|PM`, `P|PM` → `PM?|.*` / `PM?`.
    static func endQuestion(_ r: String) -> String {
        var s = r
        s = subFirst("([|(])([A-Za-z])([A-Za-z])\\|(.*)\\|\\2([|)])", s, "$1$2$3?|$4$5")
        s = subFirst("([|(])([A-Za-z])([A-Za-z])\\|\\2([|)])", s, "$1$2$3?$4")
        s = subFirst("([|(])([A-Za-z])\\|(.*)\\|\\2([A-Za-z])([|)])", s, "$1$2$4?|$3$5")
        s = subFirst("([|(])([A-Za-z])\\|\\2([A-Za-z])([|)])", s, "$1$2$3?$4")
        return s
    }

    /// Drop a duplicated alternative, e.g. `HD|.*|HD` → `HD|.*`, `HD|HD` → `HD`.
    static func removeDuplicateChars(_ r: String) -> String {
        var s = r
        s = subFirst("([|(])([A-Z]+)([|)])(.*)([|(])\\2([|)])", s, "$1$2$3$4$6")
        s = subFirst("([|(])([A-Z]+)([|(])\\2([|)])", s, "$1$2$4")
        return s
    }

    /// Collapse runs of `.*`, e.g. `.*.*` → `.*`.
    static func removeDoubleAsterisks(_ r: String) -> String {
        subAll("(\\.\\*)+", r, ".*")
    }

    /// `PH|TH` → `[PT]H`, `EL|EB` → `E[LB]` (and their `.*`-infix variants).
    static func addBrackets(_ r: String) -> String {
        var s = r
        s = subFirst("([|(])([A-Z])([A-Z])\\|([A-Z])\\3([|)])", s, "$1[$2$4]$3$5")
        s = subFirst("([|(])([A-Z])([A-Z])\\|(.*)\\|([A-Z])\\3([|)])", s, "$1[$2$5]$3|$4$6")
        s = subFirst("([|(])([A-Z])([A-Z])\\|\\2([A-Z])([|)])", s, "$1$2[$3$4]$5")
        s = subFirst("([|(])([A-Z])([A-Z])\\|(.*)\\|\\2([A-Z])([|)])", s, "$1$2[$3$5]|$4$6")
        return s
    }

    // MARK: - Templates (regexle's REGEX_RULES_TEMPLATE). `{}` = distractor.

    private static let templates: [String] = [
        ".*",
        ".*{center}.*",
        ".*{center}.*{after_substr}.*",
        ".*{before_substr}.*{center}.*",
        ".*{before_substr}.*{center}.*{after_substr}.*",
        "({before_str}|{center}|{after_str})+",
        "({center}|{after_str}|{before_str})+",
        "({after_str}|{before_str}|{center})+",
        "({}|{before_str}|{center}|{after_str})+",
        "({}|{center}|{after_str}|{before_str})+",
        "({}|{after_str}|{before_str}|{center})+",
        "({before_str}|{}|{center}|{after_str})+",
        "({center}|{}|{after_str}|{before_str})+",
        "({after_str}|{}|{before_str}|{center})+",
        "({before_str}|{center}|{}|{after_str})+",
        "({center}|{after_str}|{}|{before_str})+",
        "({after_str}|{before_str}|{}|{center})+",
        "({before_str}|{center}|{after_str}|{})+",
        "({center}|{after_str}|{before_str}|{})+",
        "({after_str}|{before_str}|{center}|{})+",
    ]
}
