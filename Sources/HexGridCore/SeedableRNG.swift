/// The "Small Fast Chaotic" PRNG (originally by Chris Doty-Humphrey)
/// Seeded as `initialize(seed, second, 0, 1)`, which discards the first 12 outputs to
/// avoid correlations between similar seeds. The `second` word loads the `b` lane, so
/// two puzzles that share a counter but differ in size (the app passes `second: n`) get
/// uncorrelated streams. It defaults to 0, matching the original single-seed behavior.
public struct SFC64: RandomNumberGenerator {
    private var a: UInt64
    private var b: UInt64
    private var c: UInt64
    private var counter: UInt64

    /// Seed from a primary 64-bit value (mirrors `seed_from_u64`) plus an optional second
    /// word that loads the `b` lane. `second == 0` reproduces the historical single-seed
    /// stream exactly, so existing call sites and tests are unaffected.
    public init(seed: UInt64, second: UInt64 = 0) {
        self.a = seed
        self.b = second
        self.c = 0
        self.counter = 1
        for _ in 0..<12 { _ = step() }   // discard 12 warm-up outputs
    }

    /// Advance one step, returning the generated 64-bit value.
    @discardableResult // We throw away data in the initialization
    private mutating func step() -> UInt64 {
        // Constants: barrel shift 24, right shift 11, left shift 3.
        let out = a &+ b &+ counter
        a = b ^ (b >> 11) // shr 11
        b = c &+ (c << 3) // shl 3
        c = ((c << 24) | (c >> 40)) &+ out // Barrel shift 24 (40 = 64-24)
        counter = counter &+ 1   // Weyl increment of 1
        return out
    }

    public mutating func next() -> UInt64 { step() }
}
