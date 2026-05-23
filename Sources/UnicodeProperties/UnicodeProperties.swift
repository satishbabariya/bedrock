public enum UnicodeProperties {

    /// The Unicode version these tables were generated from.
    public static let unicodeVersion: String = "16.0.0"

    /// O(1) general-category lookup. Returns `.unassigned` for codepoints
    /// not assigned in Unicode 16.0.
    @inlinable
    public static func generalCategory(of scalar: Unicode.Scalar) -> GeneralCategory {
        let raw = generalCategoryTable.lookup(scalar.value)
        return GeneralCategory(rawValue: raw) ?? .unassigned
    }

    /// O(1) bidi-class lookup. Defaults to `.leftToRight` for codepoints
    /// not present in UnicodeData.txt.
    @inlinable
    public static func bidiClass(of scalar: Unicode.Scalar) -> BidiClass {
        let raw = bidiClassTable.lookup(scalar.value)
        return BidiClass(rawValue: raw) ?? .leftToRight
    }

    /// O(1) canonical-combining-class lookup. Returns 0 for codepoints
    /// with no combining class (the default per UCD).
    @inlinable
    public static func canonicalCombiningClass(of scalar: Unicode.Scalar) -> UInt8 {
        canonicalCombiningClassTable.lookup(scalar.value)
    }

    /// Simple uppercase mapping (UnicodeData.txt field 12).
    /// Returns the input scalar unchanged when no mapping exists.
    ///
    /// "Simple" = single-codepoint mapping only. Multi-codepoint cases
    /// (e.g., "ß" → "SS") and locale-dependent cases (Turkish dotted/
    /// dotless I) require SpecialCasing.txt; that's a separate sub-project.
    @inlinable
    public static func simpleUppercase(of scalar: Unicode.Scalar) -> Unicode.Scalar {
        let raw = simpleUppercaseTable.lookup(scalar.value)
        return raw == 0 ? scalar : (Unicode.Scalar(raw) ?? scalar)
    }

    /// Simple lowercase mapping (UnicodeData.txt field 13).
    @inlinable
    public static func simpleLowercase(of scalar: Unicode.Scalar) -> Unicode.Scalar {
        let raw = simpleLowercaseTable.lookup(scalar.value)
        return raw == 0 ? scalar : (Unicode.Scalar(raw) ?? scalar)
    }

    /// Simple titlecase mapping (UnicodeData.txt field 14).
    @inlinable
    public static func simpleTitlecase(of scalar: Unicode.Scalar) -> Unicode.Scalar {
        let raw = simpleTitlecaseTable.lookup(scalar.value)
        return raw == 0 ? scalar : (Unicode.Scalar(raw) ?? scalar)
    }

    /// Simple case folding (CaseFolding.txt statuses C + S — single-
    /// codepoint folding only). Returns the input scalar unchanged when
    /// no folding applies.
    ///
    /// For case-insensitive comparison, folding is the correct operation
    /// (not lowercasing). Folding maps disparate cased forms (e.g., Greek
    /// "Σ" and "ς") to a single canonical form ("σ") for comparison.
    ///
    /// Multi-codepoint folding (e.g., "ß" → "ss") requires status `F`;
    /// that's a separate sub-project. Turkic-locale folding (status `T`)
    /// is locale-dependent and also deferred.
    @inlinable
    public static func caseFolded(of scalar: Unicode.Scalar) -> Unicode.Scalar {
        let raw = simpleCaseFoldingTable.lookup(scalar.value)
        return raw == 0 ? scalar : (Unicode.Scalar(raw) ?? scalar)
    }

    /// Full case folding (CaseFolding.txt statuses C + F — single OR
    /// multi-codepoint output).
    ///
    /// Returns a non-empty array of `Unicode.Scalar`:
    /// - For most codepoints (no folding): `[scalar]` (identity).
    /// - For `C`-folded codepoints: `[targetCp]` (e.g., `"A"` → `["a"]`).
    /// - For `F`-folded codepoints: 2–3 codepoints
    ///   (e.g., `"ß"` (U+00DF) → `["s", "s"]`,
    ///    `"İ"` (U+0130) → `["i", "\u{0307}"]`,
    ///    `"ﬃ"` (U+FB03) → `["f", "f", "i"]`).
    ///
    /// Turkic-locale folding (status `T`) is locale-dependent and not
    /// applied; consumers needing Turkish folding must override at a
    /// higher layer.
    @inlinable
    public static func fullCaseFolded(of scalar: Unicode.Scalar) -> [Unicode.Scalar] {
        let packed = fullCaseFoldingIndexTable.lookup(scalar.value)
        if packed == 0 { return [scalar] }
        let offset = Int(packed >> 8)
        let length = Int(packed & 0xFF)
        var result: [Unicode.Scalar] = []
        result.reserveCapacity(length)
        for i in 0..<length {
            result.append(Unicode.Scalar(fullCaseFoldingFlatTable[offset + i])!)
        }
        return result
    }

    /// Whether `scalar` is a valid identifier-start character per UAX #31
    /// (the `XID_Start` derived property — recommended for new code).
    @inlinable
    public static func isXIDStart(_ scalar: Unicode.Scalar) -> Bool {
        xidStartTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is a valid identifier-continuation character per
    /// UAX #31 (the `XID_Continue` derived property).
    ///
    /// `XID_Start ⊂ XID_Continue` — every start codepoint is also a valid
    /// continuation.
    @inlinable
    public static func isXIDContinue(_ scalar: Unicode.Scalar) -> Bool {
        xidContinueTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` has the legacy `ID_Start` property (UAX #31).
    ///
    /// `XID_Start` is recommended for new code; `ID_Start` may admit
    /// characters whose NFKx form would not be valid start characters.
    @inlinable
    public static func isIDStart(_ scalar: Unicode.Scalar) -> Bool {
        idStartTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` has the legacy `ID_Continue` property (UAX #31).
    @inlinable
    public static func isIDContinue(_ scalar: Unicode.Scalar) -> Bool {
        idContinueTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is a math symbol (`Math` property: Sm + Other_Math).
    @inlinable
    public static func isMath(_ scalar: Unicode.Scalar) -> Bool {
        mathTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is alphabetic (`Alphabetic` property:
    /// L* + Nl + Other_Alphabetic).
    @inlinable
    public static func isAlphabetic(_ scalar: Unicode.Scalar) -> Bool {
        alphabeticTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is cased (`Cased` property:
    /// Lu + Ll + Lt + Other_Uppercase + Other_Lowercase).
    @inlinable
    public static func isCased(_ scalar: Unicode.Scalar) -> Bool {
        casedTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is lowercase (`Lowercase` property: Ll + Other_Lowercase).
    @inlinable
    public static func isLowercase(_ scalar: Unicode.Scalar) -> Bool {
        lowercaseTable.lookup(scalar.value) != 0
    }

    /// Whether `scalar` is uppercase (`Uppercase` property: Lu + Other_Uppercase).
    @inlinable
    public static func isUppercase(_ scalar: Unicode.Scalar) -> Bool {
        uppercaseTable.lookup(scalar.value) != 0
    }

    /// O(1) East Asian Width lookup (UAX #11).
    ///
    /// Used by terminal layout (each codepoint occupies 1 or 2 visual
    /// columns) and CJK-aware text rendering. Returns `.neutral` for
    /// codepoints absent from `EastAsianWidth.txt` (the UCD default).
    @inlinable
    public static func eastAsianWidth(of scalar: Unicode.Scalar) -> EastAsianWidth {
        let raw = eastAsianWidthTable.lookup(scalar.value)
        return EastAsianWidth(rawValue: raw) ?? .neutral
    }

    /// O(1) bracket-type lookup (UAX #9, `Bidi_Paired_Bracket_Type`).
    ///
    /// Returns `.none` for codepoints that are not bracket characters.
    @inlinable
    public static func bidiBracketType(of scalar: Unicode.Scalar) -> BidiBracketType {
        let raw = bidiBracketTypeTable.lookup(scalar.value)
        return BidiBracketType(rawValue: raw) ?? .none
    }

    /// O(1) paired-bracket lookup (UAX #9, `Bidi_Paired_Bracket`).
    ///
    /// Returns the mirrored partner codepoint for bracket characters
    /// (e.g., `(` → `)`, `[` → `]`). Returns `nil` for non-brackets.
    @inlinable
    public static func pairedBracket(of scalar: Unicode.Scalar) -> Unicode.Scalar? {
        let paired = bidiPairedBracketTable.lookup(scalar.value)
        return paired == 0 ? nil : Unicode.Scalar(paired)
    }

    /// O(1) Grapheme_Cluster_Break lookup (UAX #29).
    ///
    /// Returns the per-codepoint GCB property value used by grapheme-
    /// cluster segmentation. Returns `.other` for codepoints absent from
    /// `GraphemeBreakProperty.txt` (the UCD default per @missing).
    @inlinable
    public static func graphemeClusterBreak(of scalar: Unicode.Scalar) -> GraphemeClusterBreak {
        let raw = graphemeClusterBreakTable.lookup(scalar.value)
        return GraphemeClusterBreak(rawValue: raw) ?? .other
    }

    /// O(1) Word_Break lookup (UAX #29).
    ///
    /// Returns the per-codepoint WB property value used by word-
    /// segmentation algorithms. Returns `.other` for codepoints absent
    /// from `WordBreakProperty.txt` (the UCD default per @missing).
    @inlinable
    public static func wordBreak(of scalar: Unicode.Scalar) -> WordBreak {
        let raw = wordBreakTable.lookup(scalar.value)
        return WordBreak(rawValue: raw) ?? .other
    }

    /// Any L* category (uppercase, lowercase, titlecase, modifier, other).
    @inlinable
    public static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .uppercaseLetter || c == .lowercaseLetter
            || c == .titlecaseLetter || c == .modifierLetter || c == .otherLetter
    }

    /// Any N* category.
    @inlinable
    public static func isNumber(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .decimalNumber || c == .letterNumber || c == .otherNumber
    }

    /// Any M* category.
    @inlinable
    public static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .nonspacingMark || c == .spacingMark || c == .enclosingMark
    }

    /// Any P* category.
    @inlinable
    public static func isPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .connectorPunctuation || c == .dashPunctuation
            || c == .openPunctuation || c == .closePunctuation
            || c == .initialPunctuation || c == .finalPunctuation
            || c == .otherPunctuation
    }

    /// Any S* category.
    @inlinable
    public static func isSymbol(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .mathSymbol || c == .currencySymbol
            || c == .modifierSymbol || c == .otherSymbol
    }

    /// Any Z* category.
    @inlinable
    public static func isSeparator(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .spaceSeparator || c == .lineSeparator || c == .paragraphSeparator
    }

    /// Any C* category.
    @inlinable
    public static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        let c = generalCategory(of: scalar)
        return c == .control || c == .format || c == .surrogate
            || c == .privateUse || c == .unassigned
    }
}
