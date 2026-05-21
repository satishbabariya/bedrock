import Testing
@testable import BedrockUcdGen

@Suite
struct DerivedCorePropertyParserTests {

    @Test
    func parsesSingleCodepointEntry() throws {
        let input = "005F          ; XID_Continue # Pc       LOW LINE\n"
        let entries = try DerivedCorePropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x005F)
        #expect(entries[0].last == 0x005F)
        #expect(entries[0].propertyName == "XID_Continue")
    }

    @Test
    func parsesRangeEntry() throws {
        let input = "0041..005A    ; XID_Start # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z\n"
        let entries = try DerivedCorePropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0041)
        #expect(entries[0].last == 0x005A)
        #expect(entries[0].propertyName == "XID_Start")
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # DerivedCoreProperties header

        # Section comment

        0041..005A    ; XID_Start # comment

        005F          ; XID_Continue # comment
        """
        let entries = try DerivedCorePropertyParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].propertyName == "XID_Start")
        #expect(entries[1].propertyName == "XID_Continue")
    }

    @Test
    func parsesMultiplePropertiesForSameRange() throws {
        let input = """
        0041..005A    ; XID_Start # comment
        0041..005A    ; XID_Continue # comment
        0041..005A    ; Alphabetic # comment
        """
        let entries = try DerivedCorePropertyParser.parse(input)
        #expect(entries.count == 3)
        #expect(entries[0].propertyName == "XID_Start")
        #expect(entries[1].propertyName == "XID_Continue")
        #expect(entries[2].propertyName == "Alphabetic")
        for e in entries {
            #expect(e.first == 0x0041)
            #expect(e.last == 0x005A)
        }
    }

    @Test
    func handlesRealisticInputWithHeader() throws {
        let input = """
        # DerivedCoreProperties-16.0.0.txt
        # Date: 2024-05-31, 18:09:32 GMT

        # ================================================

        # Derived Property: Math
        #  Generated from: Sm + Other_Math

        002B          ; Math # Sm       PLUS SIGN
        003C..003E    ; Math # Sm   [3] LESS-THAN SIGN..GREATER-THAN SIGN
        """
        let entries = try DerivedCorePropertyParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].first == 0x002B)
        #expect(entries[0].last == 0x002B)
        #expect(entries[1].first == 0x003C)
        #expect(entries[1].last == 0x003E)
        for e in entries {
            #expect(e.propertyName == "Math")
        }
    }

    @Test
    func rejectsInvalidRange() {
        let input = "0041..        ; XID_Start # comment\n"
        do {
            _ = try DerivedCorePropertyParser.parse(input)
            Issue.record("expected throw for invalid range")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX          ; XID_Start # comment\n"
        do {
            _ = try DerivedCorePropertyParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyPropertyName() {
        let input = "0041          ; # comment\n"
        do {
            _ = try DerivedCorePropertyParser.parse(input)
            Issue.record("expected throw for empty property name")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsTruncatedLine() {
        let input = "0041\n"
        do {
            _ = try DerivedCorePropertyParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }
}
