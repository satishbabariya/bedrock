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
