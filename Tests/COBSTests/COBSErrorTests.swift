import Testing
import COBS

@Suite
struct COBSErrorTests {

    @Test
    func invalidZeroByteCarriesOffset() {
        let e = COBSError.invalidZeroByte(offset: 7)
        if case .invalidZeroByte(let o) = e {
            #expect(o == 7)
        } else {
            Issue.record("expected .invalidZeroByte case")
        }
    }

    @Test
    func unexpectedTerminatorCarriesOffset() {
        let e = COBSError.unexpectedTerminator(offset: 3)
        if case .unexpectedTerminator(let o) = e {
            #expect(o == 3)
        } else {
            Issue.record("expected .unexpectedTerminator case")
        }
    }

    @Test
    func truncatedAndMissingTerminatorAreConstructible() {
        let _ = COBSError.truncated
        let _ = COBSError.missingTerminator
    }

    @Test
    func equalCasesHashEqual() {
        #expect(COBSError.truncated == COBSError.truncated)
        #expect(COBSError.missingTerminator == COBSError.missingTerminator)
        #expect(COBSError.invalidZeroByte(offset: 5)
                == COBSError.invalidZeroByte(offset: 5))
        #expect(COBSError.unexpectedTerminator(offset: 2)
                == COBSError.unexpectedTerminator(offset: 2))
    }

    @Test
    func distinctCasesAreUnequal() {
        #expect(COBSError.truncated != COBSError.missingTerminator)
        #expect(COBSError.invalidZeroByte(offset: 1)
                != COBSError.invalidZeroByte(offset: 2))
        #expect(COBSError.unexpectedTerminator(offset: 1)
                != COBSError.truncated)
    }

    @Test
    func hashableUsableInSet() {
        var s = Set<COBSError>()
        s.insert(.truncated)
        s.insert(.truncated)
        s.insert(.invalidZeroByte(offset: 1))
        s.insert(.invalidZeroByte(offset: 1))
        s.insert(.invalidZeroByte(offset: 2))
        #expect(s.count == 3)
    }

    @Test
    func errorIsSendable() {
        let e: COBSError = .truncated
        Task.detached { @Sendable in
            let _ = e
        }
    }
}
