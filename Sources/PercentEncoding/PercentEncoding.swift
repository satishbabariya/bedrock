import Bytes

/// RFC 3986 / x-www-form-urlencoded percent-encoding codec namespace.
public enum PercentEncoding {

    /// Encoding-set rules per RFC 3986 / WHATWG URL component contexts.
    public enum Set: Sendable {
        /// RFC 3986 §2.3: A–Z a–z 0–9 - _ . ~ left unencoded.
        case unreserved
        /// Path segment: unreserved + sub-delims + `:` + `@`. Encodes `/`.
        case pathSegment
        /// Query: unreserved + sub-delims (minus `&` and `=`) + `:@/?`.
        case query
        /// Fragment: unreserved + all sub-delims + `:` `@` `/` `?`.
        /// Differs from `.query` by re-including `&` and `=` (sub-delims
        /// have no special meaning inside a fragment).
        case fragment
        /// Userinfo (`user:pass`): unreserved + sub-delims + `:`.
        case userinfo
        /// Strict component: only unreserved bytes unencoded.
        case component
        /// `application/x-www-form-urlencoded`: encodes per `.component`,
        /// but maps ASCII space (0x20) to `+` instead of `%20`.
        case form
    }
}
