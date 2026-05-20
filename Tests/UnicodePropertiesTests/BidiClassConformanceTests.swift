import Testing
import UnicodeProperties

@Suite
struct BidiClassConformanceTests {

    @Test
    func hasExactly23Cases() {
        #expect(UnicodeProperties.BidiClass.allCases.count == 23)
    }

    @Test
    func rawValuesAreContiguous() {
        let raws = UnicodeProperties.BidiClass.allCases.map { $0.rawValue }
        #expect(raws == Array<UInt8>(0...22))
    }

    @Test
    func equatableHashableSmoke() {
        var set = Set<UnicodeProperties.BidiClass>()
        for c in UnicodeProperties.BidiClass.allCases {
            set.insert(c)
            set.insert(c)
        }
        #expect(set.count == 23)
    }

    @Test
    func sendable() {
        let c: UnicodeProperties.BidiClass = .leftToRight
        Task.detached { @Sendable in
            let _ = c
        }
    }
}
