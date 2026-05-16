import Testing
@testable import BitSet

@Test func iteratesAscending() {
    let s: BitSet = [5, 1, 3]
    let arr = Array(s)
    #expect(arr == [1, 3, 5])
}

@Test func iteratesAcrossWordBoundaries() {
    let s: BitSet = [0, 63, 64, 127, 128]
    let arr = Array(s)
    #expect(arr == [0, 63, 64, 127, 128])
}

@Test func iteratesEmpty() {
    let s = BitSet()
    let arr = Array(s)
    #expect(arr == [])
}

@Test func iteratesLargeSet() {
    let positions = [0, 1, 2, 7, 64, 99, 128, 255, 500]
    let s = BitSet(positions)
    #expect(Array(s) == positions.sorted())
}

@Test func firstAndLast() {
    let s: BitSet = [10, 3, 100, 50]
    #expect(s.first == 3)
    #expect(s.last == 100)
}

@Test func firstAndLastEmpty() {
    let s = BitSet()
    #expect(s.first == nil)
    #expect(s.last == nil)
}

@Test func mapWorks() {
    let s: BitSet = [1, 2, 3]
    let doubled = s.map { $0 * 2 }
    #expect(doubled == [2, 4, 6])
}
