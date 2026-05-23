import Testing
@testable import BedrockUcdGen

@Suite
struct GraphemeBreakPropertyParserTests {

    @Test
    func parsesSingleCodepointEntry() throws {
        let input = "000D          ; CR # Cc       <control-000D>\n"
        let entries = try GraphemeBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x000D)
        #expect(entries[0].last  == 0x000D)
        #expect(entries[0].value == "CR")
    }

    @Test
    func parsesRangeEntry() throws {
        let input = "0600..0605    ; Prepend # Cf   [6] ARABIC NUMBER SIGN..ARABIC NUMBER MARK ABOVE\n"
        let entries = try GraphemeBreakPropertyParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0600)
        #expect(entries[0].last  == 0x0605)
        #expect(entries[0].value == "Prepend")
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # GraphemeBreakProperty-16.0.0.txt
        # @missing: 0000..10FFFF; Other

        000D          ; CR # Cc       <control-000D>

        000A          ; LF # Cc       <control-000A>
        """
        let entries = try GraphemeBreakPropertyParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].value == "CR")
        #expect(entries[1].value == "LF")
    }

    @Test
    func parsesRealisticSnippet() throws {
        let input = """
        0000..0009    ; Control # Cc  [10] <control-0000>..<control-0009>
        000A          ; LF # Cc       <control-000A>
        000D          ; CR # Cc       <control-000D>
        0301          ; Extend # Mn       COMBINING ACUTE ACCENT
        200D          ; ZWJ # Cf       ZERO WIDTH JOINER
        1F1E6..1F1FF  ; Regional_Indicator # So  [26] REGIONAL INDICATOR SYMBOL LETTER A..Z
        """
        let entries = try GraphemeBreakPropertyParser.parse(input)
        #expect(entries.count == 6)
        #expect(entries[0].value == "Control")
        #expect(entries[0].first == 0x0000)
        #expect(entries[0].last  == 0x0009)
        #expect(entries[1].value == "LF")
        #expect(entries[2].value == "CR")
        #expect(entries[3].value == "Extend")
        #expect(entries[3].first == 0x0301)
        #expect(entries[3].last  == 0x0301)
        #expect(entries[4].value == "ZWJ")
        #expect(entries[5].value == "Regional_Indicator")
        #expect(entries[5].first == 0x1F1E6)
        #expect(entries[5].last  == 0x1F1FF)
    }

    @Test
    func rejectsTruncatedLine() {
        // No semicolon — only one field.
        let input = "000D\n"
        do {
            _ = try GraphemeBreakPropertyParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX          ; CR # comment\n"
        do {
            _ = try GraphemeBreakPropertyParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsInvalidRange() {
        // Empty second half of range.
        let input = "0600..        ; Prepend # comment\n"
        do {
            _ = try GraphemeBreakPropertyParser.parse(input)
            Issue.record("expected throw for invalid range")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyPropertyValue() {
        let input = "000D          ; # Cc comment\n"
        do {
            _ = try GraphemeBreakPropertyParser.parse(input)
            Issue.record("expected throw for empty property value")
        } catch {
            // expected
        }
    }
}
