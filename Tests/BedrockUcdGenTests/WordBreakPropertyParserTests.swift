import Testing
@testable import BedrockUcdGen

@Suite
struct WordBreakPropertyParserTests {

    @Test
    func parsesSingleCodepointEntry() throws {
        let input = "000D          ; CR # Cc       <control-000D>\n"
        let entries = try WordBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x000D)
        #expect(entries[0].last  == 0x000D)
        #expect(entries[0].value == "CR")
    }

    @Test
    func parsesRangeEntry() throws {
        let input = "0041..005A    ; ALetter # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z\n"
        let entries = try WordBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0041)
        #expect(entries[0].last  == 0x005A)
        #expect(entries[0].value == "ALetter")
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # WordBreakProperty-16.0.0.txt
        # @missing: 0000..10FFFF; Other

        000D          ; CR # Cc       <control-000D>

        000A          ; LF # Cc       <control-000A>
        """
        let entries = try WordBreakPropertyParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].value == "CR")
        #expect(entries[1].value == "LF")
    }

    @Test
    func parsesRealisticSnippet() throws {
        let input = """
        000B..000C    ; Newline # Cc   [2] <control-000B>..<control-000C>
        000A          ; LF # Cc       <control-000A>
        000D          ; CR # Cc       <control-000D>
        0022          ; Double_Quote # Po       QUOTATION MARK
        0027          ; Single_Quote # Po       APOSTROPHE
        1F1E6..1F1FF  ; Regional_Indicator # So  [26] REGIONAL INDICATOR SYMBOL LETTER A..Z
        """
        let entries = try WordBreakPropertyParser.parse(input)
        #expect(entries.count == 6)
        #expect(entries[0].value == "Newline")
        #expect(entries[0].first == 0x000B)
        #expect(entries[0].last  == 0x000C)
        #expect(entries[1].value == "LF")
        #expect(entries[2].value == "CR")
        #expect(entries[3].value == "Double_Quote")
        #expect(entries[3].first == 0x0022)
        #expect(entries[3].last  == 0x0022)
        #expect(entries[4].value == "Single_Quote")
        #expect(entries[5].value == "Regional_Indicator")
        #expect(entries[5].first == 0x1F1E6)
        #expect(entries[5].last  == 0x1F1FF)
    }

    @Test
    func rejectsTruncatedLine() {
        // No semicolon — only one field.
        let input = "000D\n"
        do {
            _ = try WordBreakPropertyParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX          ; CR # comment\n"
        do {
            _ = try WordBreakPropertyParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsInvalidRange() {
        // Empty second half of range.
        let input = "0041..        ; ALetter # comment\n"
        do {
            _ = try WordBreakPropertyParser.parse(input)
            Issue.record("expected throw for invalid range")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyPropertyValue() {
        let input = "000D          ; # Cc comment\n"
        do {
            _ = try WordBreakPropertyParser.parse(input)
            Issue.record("expected throw for empty property value")
        } catch {
            // expected
        }
    }
}
