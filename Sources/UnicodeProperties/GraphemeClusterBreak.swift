extension UnicodeProperties {

    /// Grapheme_Cluster_Break property (UAX #29). Used by grapheme-
    /// cluster segmentation to find user-perceived character boundaries.
    /// Returns `.other` for codepoints not explicitly listed in
    /// `GraphemeBreakProperty.txt` (the UCD default per @missing).
    public enum GraphemeClusterBreak: UInt8, Sendable, Hashable, CaseIterable {
        case other             = 0   // XX (default — not in UCD file)
        case cr                = 1   // CR
        case lf                = 2   // LF
        case control           = 3   // Control
        case extend            = 4   // Extend
        case zwj               = 5   // ZWJ
        case regionalIndicator = 6   // Regional_Indicator
        case prepend           = 7   // Prepend
        case spacingMark       = 8   // SpacingMark
        case l                 = 9   // L (Hangul leading jamo)
        case v                 = 10  // V (Hangul vowel jamo)
        case t                 = 11  // T (Hangul trailing jamo)
        case lv                = 12  // LV (Hangul precomposed syllable, no trailing)
        case lvt               = 13  // LVT (Hangul precomposed syllable, with trailing)
    }
}
