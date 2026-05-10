#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(WinSDK)
import WinSDK
#endif

/// Milliseconds since the Unix epoch (1970-01-01 UTC).
/// Internal — only used by v7 generation.
@usableFromInline
internal func unixWallClockMilliseconds() -> Int64 {
    #if canImport(Darwin) || canImport(Glibc) || canImport(Musl)
    var ts = timespec()
    _ = clock_gettime(CLOCK_REALTIME, &ts)
    return Int64(ts.tv_sec) * 1000 + Int64(ts.tv_nsec) / 1_000_000
    #elseif canImport(WinSDK)
    var ft = FILETIME()
    GetSystemTimePreciseAsFileTime(&ft)
    let intervals = (UInt64(ft.dwHighDateTime) << 32) | UInt64(ft.dwLowDateTime)
    let unixEpoch100ns: UInt64 = 116444736000000000
    return Int64((intervals &- unixEpoch100ns) / 10_000)
    #else
    fatalError("No platform clock available for unixWallClockMilliseconds()")
    #endif
}
