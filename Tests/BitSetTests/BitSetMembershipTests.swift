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
