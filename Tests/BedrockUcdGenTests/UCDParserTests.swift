import Testing
@testable import BedrockUcdGen

@Suite
struct UCDParserTests {

    @Test
    func parsesSingleAsciiLine() throws {
        let input = "0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;\n"
        let entries = try UCDParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x0041)
        #expect(entries[0].last == 0x0041)
        #expect(entries[0].category == "Lu")
        #expect(entries[0].canonicalCombiningClass == 0)
        #expect(entries[0].bidiClass == "L")
    }

    @Test
    func parsesMultipleLines() throws {
        let input = """
        0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;
        0042;LATIN CAPITAL LETTER B;Lu;0;L;;;;;N;;;;0062;
        0061;LATIN SMALL LETTER A;Ll;0;L;;;;;N;;;0041;;0041
        """
        let entries = try UCDParser.parse(input)
        #expect(entries.count == 3)
        #expect(entries[0].first == 0x0041)
        #expect(entries[1].first == 0x0042)
        #expect(entries[2].category == "Ll")
        #expect(entries[0].canonicalCombiningClass == 0)
        #expect(entries[0].bidiClass == "L")
    }

    @Test
    func parsesRangePair() throws {
        let input = """
        4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;
        9FFF;<CJK Ideograph, Last>;Lo;0;L;;;;;N;;;;;
        """
        let entries = try UCDParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].first == 0x4E00)
        #expect(entries[0].last == 0x9FFF)
        #expect(entries[0].category == "Lo")
        #expect(entries[0].canonicalCombiningClass == 0)
        #expect(entries[0].bidiClass == "L")
    }

    @Test
    func parsesMixedSingleAndRange() throws {
        let input = """
        0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;
        4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;
        9FFF;<CJK Ideograph, Last>;Lo;0;L;;;;;N;;;;;
        AC00;<Hangul Syllable, First>;Lo;0;L;;;;;N;;;;;
        D7A3;<Hangul Syllable, Last>;Lo;0;L;;;;;N;;;;;
        """
        let entries = try UCDParser.parse(input)
        #expect(entries.count == 3)
        #expect(entries[0].first == 0x0041)
        #expect(entries[0].last == 0x0041)
        #expect(entries[1].first == 0x4E00)
        #expect(entries[1].last == 0x9FFF)
        #expect(entries[2].first == 0xAC00)
        #expect(entries[2].last == 0xD7A3)
    }

    @Test
    func ignoresEmptyLines() throws {
        let input = """

        0041;LATIN CAPITAL LETTER A;Lu;0;L;;;;;N;;;;0061;

        """
        let entries = try UCDParser.parse(input)
        #expect(entries.count == 1)
    }

    @Test
    func rejectsTruncatedLine() {
        let input = "0041;LATIN;Lu\n"
        do {
            _ = try UCDParser.parse(input)
            Issue.record("expected parse error on truncated line")
        } catch {
            // expected
        }
    }

    @Test
    func rejectsUnmatchedRangeMarker() {
        let input = "4E00;<CJK Ideograph, First>;Lo;0;L;;;;;N;;;;;\n"
        do {
            _ = try UCDParser.parse(input)
            Issue.record("expected parse error on unmatched First")
        } catch {
            // expected
        }
    }

    @Test
    func parsesNonZeroCCCAndNonLBidi() throws {
        // U+0300 COMBINING GRAVE ACCENT: CCC=230, bidi=NSM
        let input = "0300;COMBINING GRAVE ACCENT;Mn;230;NSM;;;;;N;;;;;\n"
        let entries = try UCDParser.parse(input)
        #expect(entries.count == 1)
        #expect(entries[0].canonicalCombiningClass == 230)
        #expect(entries[0].bidiClass == "NSM")
    }

    @Test
    func rejectsNonNumericCCC() {
        let input = "0041;LATIN CAPITAL LETTER A;Lu;notanumber;L;;;;;N;;;;0061;\n"
        do {
            _ = try UCDParser.parse(input)
            Issue.record("expected parse error on non-numeric CCC")
        } catch {
            // expected
        }
    }
}
