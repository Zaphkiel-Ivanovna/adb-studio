import Foundation

/// Severity for crash-reporting breadcrumbs, mirrored to the SDK level inside the implementation so
/// that no SDK type leaks into this protocol or its call sites.
enum CrashReportingLevel {
    case debug
    case info
    case warning
    case error
    case fatal
}

/// Boundary for crash & error reporting. The concrete implementation wraps the Sentry SDK; this
/// protocol exposes only Foundation/Swift types so the rest of the app never imports Sentry and no
/// global SDK state leaks past the service (respects the project's no-singleton / no-`.shared` rule).
///
/// Capture methods are safe to call from any thread and are a no-op until the SDK is active
/// (consent granted). Lifecycle methods (`start`/`setConsent`/`flush`) are invoked from the main actor.
protocol CrashReportingService: AnyObject, Sendable {
    /// Installs the crash handlers and starts the SDK **iff** `consent != .denied`. Idempotent.
    /// Must be called as early as possible so native crash handlers cover subsequent code.
    func start(consent: AppSettings.CrashReportingConsent)

    /// Reacts to a live consent change. `.denied` flushes then closes the client; otherwise starts it.
    func setConsent(_ consent: AppSettings.CrashReportingConsent)

    /// Captures a non-fatal error. The event's message is scrubbed of PII before sending.
    func capture(_ error: Error, context: [String: String]?)

    /// Records a scrubbed breadcrumb for context (no event is sent).
    func addBreadcrumb(category: String, message: String, level: CrashReportingLevel)

    /// Drains pending events, bounded by `timeout`, before the app terminates.
    func flush(timeout: TimeInterval) async
}

extension CrashReportingService {
    func capture(_ error: Error) {
        capture(error, context: nil)
    }
}
