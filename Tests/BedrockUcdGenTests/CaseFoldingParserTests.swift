import Testing
@testable import BedrockUcdGen

@Suite
struct CaseFoldingParserTests {

    @Test
    func parsesCommonEntry() throws {
        let input = "0041; C; 0061; # LATIN CAPITAL LETTER A\n"
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].codepoint == 0x0041)
        #expect(entries[0].status == .common)
        #expect(entries[0].mapping == [0x0061])
    }

    @Test
    func parsesFullEntry() throws {
        let input = "00DF; F; 0073 0073; # LATIN SMALL LETTER SHARP S\n"
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].codepoint == 0x00DF)
        #expect(entries[0].status == .full)
        #expect(entries[0].mapping == [0x0073, 0x0073])
    }

    @Test
    func parsesSimpleEntry() throws {
        let input = "1E9E; S; 00DF; # LATIN CAPITAL LETTER SHARP S\n"
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].status == .simple)
        #expect(entries[0].mapping == [0x00DF])
    }

    @Test
    func parsesTurkicEntry() throws {
        let input = "0130; T; 0069; # LATIN CAPITAL LETTER I WITH DOT ABOVE\n"
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].status == .turkic)
        #expect(entries[0].mapping == [0x0069])
    }

    @Test
    func ignoresCommentsAndBlankLines() throws {
        let input = """
        # CaseFolding-16.0.0.txt
        # Comment line

        0041; C; 0061; # LATIN CAPITAL LETTER A

        # Another comment
        0042; C; 0062; # LATIN CAPITAL LETTER B
        """
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 2)
        #expect(entries[0].codepoint == 0x0041)
        #expect(entries[1].codepoint == 0x0042)
    }

    @Test
    func parsesMixedStatusesInRealisticInput() throws {
        let input = """
        # Header
        0041; C; 0061; # LATIN CAPITAL LETTER A
        00DF; F; 0073 0073; # ß
        0130; F; 0069 0307; # İ full
        0130; T; 0069; # İ turkic
        1E9E; S; 00DF; # ẞ
        """
        let entries = try CaseFoldingParser.parse(input)
        #expect(entries.count == 5)
        #expect(entries[0].status == .common)
        #expect(entries[1].status == .full)
        #expect(entries[2].status == .full)
        #expect(entries[3].status == .turkic)
        #expect(entries[4].status == .simple)
    }

    @Test
    func rejectsInvalidStatus() {
        let input = "0041; Z; 0061;\n"
        do {
            _ = try CaseFoldingParser.parse(input)
            Issue.record("expected throw for invalid status")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsNonHexCodepoint() {
        let input = "XXXX; C; 0061;\n"
        do {
            _ = try CaseFoldingParser.parse(input)
            Issue.record("expected throw for non-hex codepoint")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsEmptyMapping() {
        let input = "0041; C; ;\n"
        do {
            _ = try CaseFoldingParser.parse(input)
            Issue.record("expected throw for empty mapping")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsTruncatedLine() {
        let input = "0041; C;\n"
        do {
            _ = try CaseFoldingParser.parse(input)
            Issue.record("expected throw for truncated line")
        } catch {
            // expected
        }
    }
}
