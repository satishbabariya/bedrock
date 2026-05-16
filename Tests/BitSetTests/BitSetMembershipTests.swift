import Testing
import Bytes
@testable import BitSet

@Test func emptyBitSetState() {
    let s = BitSet()
    #expect(s.count == 0)
    #expect(s.isEmpty == true)
}

@Test func initFromSequence() {
    let s = BitSet([1, 3, 5])
    #expect(s.count == 3)
    #expect(s.isEmpty == false)
}

@Test func initFromEmptySequence() {
    let s = BitSet([Int]())
    #expect(s.count == 0)
    #expect(s.isEmpty == true)
}

@Test func initWithMinimumCapacity() {
    let s = BitSet(minimumCapacity: 1000)
    #expect(s.count == 0)
    #expect(s.isEmpty == true)
}

@Test func containsAndInsertSingleBit() {
    var s = BitSet()
    #expect(s.contains(7) == false)
    let result = s.insert(7)
    #expect(result.inserted == true)
    #expect(result.memberAfterInsert == 7)
    #expect(s.contains(7) == true)
    #expect(s.count == 1)
}

@Test func insertExistingReturnsFalse() {
    var s = BitSet([7])
    let result = s.insert(7)
    #expect(result.inserted == false)
    #expect(result.memberAfterInsert == 7)
    #expect(s.count == 1)
}

@Test func insertAcrossWordBoundary() {
    var s = BitSet()
    s.insert(7)
    s.insert(64)
    s.insert(128)
    #expect(s.count == 3)
    #expect(s.contains(7))
    #expect(s.contains(64))
    #expect(s.contains(128))
    #expect(s.contains(63) == false)
}

@Test func removeReturnsValueOrNil() {
    var s = BitSet([7])
    #expect(s.remove(7) == 7)
    #expect(s.remove(7) == nil)
    #expect(s.contains(7) == false)
}

@Test func toggleSetsAndClears() {
    var s = BitSet()
    s.toggle(3)
    #expect(s.contains(3))
    s.toggle(3)
    #expect(s.contains(3) == false)
}

@Test func containsBeyondStorageReturnsFalse() {
    let s = BitSet()
    // No allocation triggered; should just return false.
    #expect(s.contains(1_000_000) == false)
}

@Test func removeNegativeReturnsNil() {
    var s = BitSet([1, 2, 3])
    // Set.remove convention: nil for missing element, no trap on negative.
    #expect(s.remove(-1) == nil)
}

@Test func updateReturnsNilOnFirstInsert() {
    var s = BitSet()
    #expect(s.update(with: 5) == nil)
    #expect(s.update(with: 5) == 5)
}
