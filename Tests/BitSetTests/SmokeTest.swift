import Testing
@testable import BitSet

@Test func bitSetNamespaceExists() {
    let _ = BitSet()
    #expect(true)
}
