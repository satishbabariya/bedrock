import Testing
import UTF8Validator

@Suite
struct UTF8ValidatorResultTests {

    @Test
    func validIsConstructible() {
        let r: UTF8Validator.ValidationResult = .valid
        #expect(r == .valid)
    }

    @Test
    func invalidCarriesOffset() {
        let r: UTF8Validator.ValidationResult = .invalid(offset: 7)
        if case .invalid(let o) = r {
            #expect(o == 7)
        } else {
            Issue.record("expected .invalid case")
        }
    }

    @Test
    func equality() {
        #expect(UTF8Validator.ValidationResult.valid
                == UTF8Validator.ValidationResult.valid)
        #expect(UTF8Validator.ValidationResult.invalid(offset: 3)
                == UTF8Validator.ValidationResult.invalid(offset: 3))
        #expect(UTF8Validator.ValidationResult.invalid(offset: 3)
                != UTF8Validator.ValidationResult.invalid(offset: 4))
        #expect(UTF8Validator.ValidationResult.valid
                != UTF8Validator.ValidationResult.invalid(offset: 0))
    }

    @Test
    func hashableUsableInSet() {
        var s = Set<UTF8Validator.ValidationResult>()
        s.insert(.valid)
        s.insert(.valid)
        s.insert(.invalid(offset: 1))
        s.insert(.invalid(offset: 1))
        s.insert(.invalid(offset: 2))
        #expect(s.count == 3)
    }

    @Test
    func sendable() {
        let r: UTF8Validator.ValidationResult = .valid
        Task.detached { @Sendable in
            let _ = r
        }
    }
}
