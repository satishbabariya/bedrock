import Testing
@testable import BedrockUcdGen

@Suite
struct SentenceBreakPropertyParserTests {

    @Test
    func parsesSingleCodepointEntry() throws {
        let input = "000D          ; CR # Cc       <control-000D>\n"
        let entries = try SentenceBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x000D)
        #expect(entries[0].last  == 0x000D)
        #expect(entries[0].value == "CR")
    }

    @Test
    func parsesRangeEntry() throws {
        let input = "0061..007A    ; Lower # L&  [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z\n"
        let entries = try SentenceBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0061)
        #expect(entries[0].last  == 0x007A)
        #expect(entries[0].value == "Lower")
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # SentenceBreakProperty-16.0.0.txt
        # @missing: 0000..10FFFF; Other

        000D          ; CR # Cc       <control-000D>

        000A          ; LF # Cc       <control-000A>
        """
        let entries = try SentenceBreakPropertyParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].value == "CR")
        #expect(entries[1].value == "LF")
    }

    @Test
    func parsesRealisticSnippet() throws {
        let input = """
        000D          ; CR # Cc       <control-000D>
        000A          ; LF # Cc       <control-000A>
        0085          ; Sep # Cc       <control-0085>
        0020          ; Sp # Zs       SPACE
        0041..005A    ; Upper # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z
        0061..007A    ; Lower # L&  [26] LATIN SMALL LETTER A..LATIN SMALL LETTER Z
        """
        let entries = try SentenceBreakPropertyParser.parse(input)
        #expect(entries.count == 6)
        #expect(entries[0].value == "CR")
        #expect(entries[1].value == "LF")
        #expect(entries[2].value == "Sep")
        #expect(entries[2].first == 0x0085)
        #expect(entries[2].last  == 0x0085)
        #expect(entries[3].value == "Sp")
        #expect(entries[4].value == "Upper")
        #expect(entries[4].first == 0x0041)
        #expect(entries[4].last  == 0x005A)
        #expect(entries[5].value == "Lower")
        #expect(entries[5].first == 0x0061)
        #expect(entries[5].last  == 0x007A)
    }

    @Test
    func rejectsTruncatedLine() {
        // No semicolon — only one field.
        let input = "000D\n"
        do {
            _ = try SentenceBreakPropertyParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX          ; CR # comment\n"
        do {
            _ = try SentenceBreakPropertyParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsInvalidRange() {
        // Empty second half of range.
        let input = "0061..        ; Lower # comment\n"
        do {
            _ = try SentenceBreakPropertyParser.parse(input)
            Issue.record("expected throw for invalid range")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyPropertyValue() {
        let input = "000D          ; # Cc comment\n"
        do {
            _ = try SentenceBreakPropertyParser.parse(input)
            Issue.record("expected throw for empty property value")
        } catch {
            // expected
        }
    }
}
