extension UnicodeProperties {

    /// Bidi paired bracket type (UAX #9, `Bidi_Paired_Bracket_Type`).
    /// Used by the UAX #9 bidi algorithm to handle paired brackets in
    /// mixed-directional text. Returns `.none` for codepoints that are
    /// not bracket characters (the default per UCD).
    public enum BidiBracketType: UInt8, Sendable, Hashable, CaseIterable {
        case none  = 0
        case open  = 1
        case close = 2
    }
}
