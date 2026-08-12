import Foundation

/// Pure, signal-safe redaction of personally identifiable information before it leaves the process.
///
/// Used by `CrashReportingServiceImpl`'s `beforeSend` / `beforeBreadcrumb` / `beforeSendSpan` hooks,
/// which can run in a post-crash (SIGABRT) context. Every operation here therefore avoids I/O,
/// `FileManager`, locale-dependent APIs, and allocation-heavy work — only precompiled
/// `NSRegularExpression` instances (static, compiled once) and plain `String` operations are used.
///
/// The instance is immutable after construction (regex set is static, the literal `secrets` list is a
/// `let`), so it is trivially `Sendable` and lock-free — safe to read from any thread or crash handler.
///
/// Known limitation: only the literal `secrets` seeded at construction (the macOS user name) are
/// stripped verbatim. Device serials/adbIds discovered *after* launch are covered only by the
/// structural regexes (IP, paths, mDNS, ports), not by exact match.
struct PIIScrubber: Sendable {

    /// Literal strings stripped verbatim (e.g. the macOS short user name, known device serials/adbIds).
    private let secrets: [String]

    init(secrets: [String] = []) {
        // Drop empties so an unseeded scrubber never replaces the whole string with the marker.
        self.secrets = secrets.filter { !$0.isEmpty }
    }

    // MARK: - Redaction

    /// Redacts every known PII pattern from `input`. Order matters: structural patterns first,
    /// then literal secrets, so a redacted token is never re-matched.
    func redact(_ input: String) -> String {
        guard !input.isEmpty else { return input }
        var output = input

        // IPv4 (and the common host:port form) -> [IP] / [IP:PORT]
        output = Self.ipv4WithPort.replacing(in: output, with: "[IP:PORT]")
        output = Self.ipv4.replacing(in: output, with: "[IP]")
        // IPv6 (loose) -> [IP]
        output = Self.ipv6.replacing(in: output, with: "[IP]")
        // Home directory paths -> /Users/[USER]
        output = Self.homePath.replacing(in: output, with: "/Users/[USER]")
        // mDNS adb service names embedding a serial -> [DEVICE]
        output = Self.mdnsService.replacing(in: output, with: "[DEVICE]")
        // Port-forward specifiers -> tcp:[PORT]
        output = Self.tcpPort.replacing(in: output, with: "tcp:[PORT]")
        // Bare 6-digit sequences (pairing codes) -> [REDACTED]
        output = Self.sixDigit.replacing(in: output, with: "[REDACTED]")

        // Literal secrets (user name, seeded device identifiers) -> [REDACTED]
        for secret in secrets {
            output = output.replacingOccurrences(of: secret, with: "[REDACTED]")
        }

        return output
    }

    /// Recursively redacts string values inside a breadcrumb/context dictionary.
    /// Non-string scalars are passed through; nested dictionaries/arrays are walked.
    func redact(_ dictionary: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        result.reserveCapacity(dictionary.count)
        for (key, value) in dictionary {
            result[key] = redactValue(value)
        }
        return result
    }

    private func redactValue(_ value: Any) -> Any {
        switch value {
        case let string as String:
            return redact(string)
        case let nested as [String: Any]:
            return redact(nested)
        case let array as [Any]:
            return array.map { redactValue($0) }
        default:
            return value
        }
    }

    // MARK: - Precompiled patterns

    private static let ipv4WithPort = CompiledPattern(#"\b(?:\d{1,3}\.){3}\d{1,3}:\d{1,5}\b"#)
    private static let ipv4 = CompiledPattern(#"\b(?:\d{1,3}\.){3}\d{1,3}\b"#)
    private static let ipv6 = CompiledPattern(#"\b(?:[A-Fa-f0-9]{1,4}:){2,7}[A-Fa-f0-9]{1,4}\b"#)
    private static let homePath = CompiledPattern(#"/Users/[^/\s"']+"#)
    private static let mdnsService = CompiledPattern(#"adb-[^.\s]+\._adb[^\s"']*"#)
    private static let tcpPort = CompiledPattern(#"\btcp:\d{1,5}"#)
    private static let sixDigit = CompiledPattern(#"\b\d{6}\b"#)
}

/// Thin wrapper around a once-compiled `NSRegularExpression`. A failed compile yields an inert
/// pattern (no-op replace) so a malformed literal can never crash the scrubber at runtime.
private struct CompiledPattern: Sendable {
    private let regex: NSRegularExpression?

    init(_ pattern: String) {
        self.regex = try? NSRegularExpression(pattern: pattern)
    }

    func replacing(in input: String, with template: String) -> String {
        guard let regex else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: template)
    }
}
