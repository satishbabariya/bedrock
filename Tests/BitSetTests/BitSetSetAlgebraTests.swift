import Testing
@testable import BitSet

@Test func arrayLiteralInit() {
    let s: BitSet = [1, 3, 5]
    #expect(s.contains(1))
    #expect(s.contains(3))
    #expect(s.contains(5))
    #expect(s.count == 3)
}

@Test func unionMatchesHandComputed() {
    let a: BitSet = [1, 3, 5]
    let b: BitSet = [3, 5, 7]
    let u = a.union(b)
    #expect(u.count == 4)
    for bit in [1, 3, 5, 7] { #expect(u.contains(bit)) }
}

@Test func intersectionMatchesHandComputed() {
    let a: BitSet = [1, 3, 5]
    let b: BitSet = [3, 5, 7]
    let i = a.intersection(b)
    #expect(i.count == 2)
    for bit in [3, 5] { #expect(i.contains(bit)) }
    #expect(i.contains(1) == false)
    #expect(i.contains(7) == false)
}

@Test func subtractingMatchesHandComputed() {
    let a: BitSet = [1, 3, 5]
    let b: BitSet = [3, 5, 7]
    let d = a.subtracting(b)
    #expect(d.count == 1)
    #expect(d.contains(1))
}

@Test func symmetricDifferenceMatchesHandComputed() {
    let a: BitSet = [1, 3, 5]
    let b: BitSet = [3, 5, 7]
    let sd = a.symmetricDifference(b)
    #expect(sd.count == 2)
    #expect(sd.contains(1))
    #expect(sd.contains(7))
    #expect(sd.contains(3) == false)
    #expect(sd.contains(5) == false)
}

@Test func operatorsMatchMethodForm() {
    let a: BitSet = [1, 3, 5]
    let b: BitSet = [3, 5, 7]
    #expect(a | b == a.union(b))
    #expect(a & b == a.intersection(b))
    #expect(a - b == a.subtracting(b))
    #expect(a ^ b == a.symmetricDifference(b))
}

@Test func inPlaceFormsMutate() {
    var a: BitSet = [1, 3, 5]
    var b = a
    b.formUnion([7])
    a |= [7]
    #expect(a == b)
    #expect(a.contains(7))
}

@Test func subsetSupersetDisjoint() {
    let small: BitSet = [1, 3]
    let big: BitSet = [1, 3, 5, 7]
    let other: BitSet = [5, 6]  // disjoint from small {1,3}, but shares 5 with big {1,3,5,7}
    #expect(small.isSubset(of: big))
    #expect(big.isSuperset(of: small))
    #expect(small.isStrictSubset(of: big))
    #expect(big.isStrictSuperset(of: small))
    #expect(small.isDisjoint(with: other))
    #expect(big.isDisjoint(with: other) == false)
}

@Test func selfOperationsAreIdentitiesOrEmpty() {
    let a: BitSet = [1, 3, 5]
    #expect(a.union(a) == a)
    #expect(a.intersection(a) == a)
    #expect(a.subtracting(a).isEmpty)
    #expect(a.symmetricDifference(a).isEmpty)
}

@Test func unionWithEmpty() {
    let a: BitSet = [1, 2, 3]
    let empty = BitSet()
    #expect(empty.union(a) == a)
    #expect(a.union(empty) == a)
}

@Test func mismatchedLengthOperands() {
    // One operand spans many words; the other is short.
    let big = BitSet((0..<200).map { $0 })
    let small: BitSet = [1, 100, 199]
    let u = big.union(small)
    #expect(u.count == 200)
    let i = big.intersection(small)
    #expect(i == small)
    let d = small.subtracting(big)
    #expect(d.isEmpty)
}
