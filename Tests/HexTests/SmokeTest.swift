import Testing
@testable import Hex

@Test func hexNamespaceExists() {
    let _: Hex.Case = .lower
    #expect(true)
}
