import Testing
@testable import BedrockUcdGen

@Suite
struct BidiBracketsParserTests {

    @Test
    func parsesSingleOpenEntry() throws {
        let input = "0028; 0029; o # LEFT PARENTHESIS\n"
        let entries = try BidiBracketsParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].codepoint       == 0x0028)
        #expect(entries[0].pairedCodepoint == 0x0029)
        #expect(entries[0].type            == .open)
    }

    @Test
    func parsesSingleCloseEntry() throws {
        let input = "0029; 0028; c # RIGHT PARENTHESIS\n"
        let entries = try BidiBracketsParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].codepoint       == 0x0029)
        #expect(entries[0].pairedCodepoint == 0x0028)
        #expect(entries[0].type            == .close)
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # BidiBrackets-16.0.0.txt
        # Date: 2024-02-02

        0028; 0029; o # LEFT PARENTHESIS

        0029; 0028; c # RIGHT PARENTHESIS
        """
        let entries = try BidiBracketsParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].type == .open)
        #expect(entries[1].type == .close)
    }

    @Test
    func parsesRealisticSnippetWithFileHeader() throws {
        let input = """
        # BidiBrackets-16.0.0.txt
        # Date: 2024-02-02
        # © 2024 Unicode®, Inc.

        0028; 0029; o # LEFT PARENTHESIS
        0029; 0028; c # RIGHT PARENTHESIS
        005B; 005D; o # LEFT SQUARE BRACKET
        005D; 005B; c # RIGHT SQUARE BRACKET
        007B; 007D; o # LEFT CURLY BRACKET
        007D; 007B; c # RIGHT CURLY BRACKET
        """
        let entries = try BidiBracketsParser.parse(input)
        #expect(entries.count == 6)
        #expect(entries[0].codepoint == 0x0028)
        #expect(entries[2].codepoint == 0x005B)
        #expect(entries[4].codepoint == 0x007B)
        #expect(entries[5].type == .close)
    }

    @Test
    func rejectsTruncatedLine() {
        let input = "0028; 0029\n"   // missing type field
        do {
            _ = try BidiBracketsParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX; 0029; o # comment\n"
        do {
            _ = try BidiBracketsParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsInvalidTypeCharacter() {
        let input = "0028; 0029; x # bad type\n"
        do {
            _ = try BidiBracketsParser.parse(input)
            Issue.record("expected throw for invalid type character")
        } catch {
            // expected
        }
    }
}
