import Testing
@testable import BedrockUcdGen

@Suite
struct EastAsianWidthParserTests {

    @Test
    func parsesSingleCodepointEntry() throws {
        let input = "0020;Na          # Zs       SPACE\n"
        let entries = try EastAsianWidthParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0020)
        #expect(entries[0].last  == 0x0020)
        #expect(entries[0].value == "Na")
    }

    @Test
    func parsesRangeEntry() throws {
        let input = "3001..3003;W     # Po   [3] IDEOGRAPHIC COMMA..DITTO MARK\n"
        let entries = try EastAsianWidthParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x3001)
        #expect(entries[0].last  == 0x3003)
        #expect(entries[0].value == "W")
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # EastAsianWidth-16.0.0.txt
        # Date: 2024-04-30

        0020;Na          # Zs       SPACE

        3001..3003;W     # Po   [3] IDEOGRAPHIC COMMA..DITTO MARK
        """
        let entries = try EastAsianWidthParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].value == "Na")
        #expect(entries[1].value == "W")
    }

    @Test
    func parsesAllSixCodes() throws {
        let input = """
        0020;Na # test
        3000;F  # test
        FF61;H  # test
        0391;A  # test
        0000;N  # test
        6F22;W  # test
        """
        let entries = try EastAsianWidthParser.parse(input)
        #expect(entries.count == 6)
        let values = entries.map(\.value)
        #expect(values.contains("Na"))
        #expect(values.contains("F"))
        #expect(values.contains("H"))
        #expect(values.contains("A"))
        #expect(values.contains("N"))
        #expect(values.contains("W"))
    }

    @Test
    func rejectsTruncatedLine() {
        let input = "0020\n"
        do {
            _ = try EastAsianWidthParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX;Na # comment\n"
        do {
            _ = try EastAsianWidthParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsInvalidRange() {
        let input = "0020..;W # comment\n"
        do {
            _ = try EastAsianWidthParser.parse(input)
            Issue.record("expected throw for invalid range")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyPropertyValue() {
        let input = "0020; # comment\n"
        do {
            _ = try EastAsianWidthParser.parse(input)
            Issue.record("expected throw for empty property value")
        } catch {
            // expected
        }
    }
}
