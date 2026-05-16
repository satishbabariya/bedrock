import Testing
@testable import BitSet

@Test func equalForSameBits() {
    let a: BitSet = [1, 2, 3]
    let b: BitSet = [1, 2, 3]
    #expect(a == b)
}

@Test func unequalForDifferentBits() {
    let a: BitSet = [1, 2, 3]
    let b: BitSet = [1, 2, 4]
    #expect(a != b)
}

@Test func equalDespiteTrailingZeroWords() {
    let a = BitSet([1, 2, 3])
    var b = BitSet([1, 2, 3])
    // Force `b` to have extra trailing zero words by inserting then removing
    // a bit in a high word.
    b.insert(1000)
    b.remove(1000)
    // Storage diverges (b has more trailing zero words), but logical sets match.
    #expect(a.storage.count != b.storage.count)
    #expect(a == b)
    // And hashing is consistent.
    var seen: Set<BitSet> = []
    seen.insert(a)
    #expect(seen.contains(b))
}

@Test func emptyBitSetsAllEqual() {
    let a = BitSet()
    let b = BitSet([Int]())
    var c = BitSet([5])
    c.remove(5)
    #expect(a == b)
    #expect(b == c)
}

@Test func sendableConformance() async {
    // Compile-time check: BitSet must be Sendable to cross actor boundaries.
    let s: BitSet = [1, 2, 3]
    let result = await withCheckedContinuation { (cont: CheckedContinuation<Int, Never>) in
        Task.detached {
            cont.resume(returning: s.count)
        }
    }
    #expect(result == 3)
}

@Test func descriptionFormat() {
    let s: BitSet = [3, 1, 7]
    #expect(s.description == "BitSet{1, 3, 7}")
}

@Test func descriptionEmpty() {
    let s = BitSet()
    #expect(s.description == "BitSet{}")
}
