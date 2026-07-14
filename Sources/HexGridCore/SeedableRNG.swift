/// The "Small Fast Chaotic" PRNG (originally by Chris Doty-Humphrey)
/// Seeded from a single `UInt64` as `initialize(seed, 0, 0, 1)`, which discards the
/// first 12 outputs to avoid correlations between similar seeds.
public struct SFC64: RandomNumberGenerator {
    private var a: UInt64
    private var b: UInt64
    private var c: UInt64
    private var counter: UInt64

    /// Seed from a single 64-bit value (mirrors `seed_from_u64`).
    public init(seed: UInt64) {
        self.a = seed
        self.b = 0
        self.c = 0
        self.counter = 1
        for _ in 0..<12 { _ = step() }   // discard 12 warm-up outputs
    }

    /// Advance one step, returning the generated 64-bit value.
    @discardableResult
    private mutating func step() -> UInt64 {
        // Constants: barrel shift 24, right shift 11, left shift 3.
        let out = a &+ b &+ counter
        a = b ^ (b >> 11)
        b = c &+ (c << 3)
        c = ((c << 24) | (c >> 40)) &+ out   // rotate-left(c, 24) for UInt64
        counter = counter &+ 1   // Weyl increment of 1
        return out
    }

    public mutating func next() -> UInt64 { step() }
}
