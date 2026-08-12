import Foundation
import Sentry

/// Sentry-backed implementation of ``CrashReportingService``. This is the **only** file that imports
/// Sentry — every SDK call is confined here so no SDK type leaks into the rest of the app.
///
/// Marked `@unchecked Sendable`: the active flag is guarded by an `NSLock`, the scrubber and
/// installation id are immutable, and the SDK statics are themselves thread-safe. Lifecycle methods
/// (`start`/`setConsent`/`flush`) are only ever called from the main actor; `capture`/`addBreadcrumb`
/// are safe from any thread.
final class CrashReportingServiceImpl: CrashReportingService, @unchecked Sendable {
    private let lock = NSLock()
    private var activeFlag = false
    private let installationID: String
    private let scrubber: PIIScrubber

    private var isActive: Bool {
        lock.lock(); defer { lock.unlock() }
        return activeFlag
    }

    /// - Parameter installationID: anonymous, persisted random UUID — the only identifier ever sent.
    init(installationID: String) {
        self.installationID = installationID
        // Seed the scrubber with the local user name so home-dir paths are stripped even when they
        // appear in an unexpected form. Captured once; immutable thereafter (signal-safe).
        self.scrubber = PIIScrubber(secrets: [NSUserName()])
    }

    // MARK: - Lifecycle

    func start(consent: AppSettings.CrashReportingConsent) {
        guard consent != .denied else { return }
        guard !isActive else { return }
        guard let dsn = Self.resolvedDSN else { return }               // not configured -> stay inert
        guard Self.isTrustedDSN(dsn) else { return }                   // untrusted host -> stay inert

        let scrubber = self.scrubber
        SentrySDK.start { options in
            options.dsn = dsn
            options.releaseName = Self.releaseName
            options.dist = Self.dist
            options.environment = Self.environment
            options.sendDefaultPii = false

            // Crash coverage (the motivating SIGABRT / NSException class).
            options.enableCrashHandler = true
            options.attachStacktrace = true
            options.enableAppHangTracking = true
            options.enableWatchdogTerminationTracking = true

            // Sessions (release-health / crash-free rate / regression detection).
            options.enableAutoSessionTracking = true

            // Performance + profiling (maximum coverage). Profiling is trace-driven (9.x API):
            // it starts/stops with traces and also captures app-start activity.
            options.enableAutoPerformanceTracing = true
            options.tracesSampleRate = 1.0
            options.configureProfiling = {
                $0.lifecycle = .trace
                $0.sessionSampleRate = 1.0
                $0.profileAppStarts = true
            }

            // Data minimization.
            options.maxBreadcrumbs = 50

            // PII scrubbing — runs for every event, breadcrumb and span (incl. performance
            // transactions) before anything leaves the process.
            options.beforeSend = { event in Self.scrub(event, with: scrubber) }
            options.beforeBreadcrumb = { crumb in Self.scrub(crumb, with: scrubber) }
            options.beforeSendSpan = { span in Self.scrub(span, with: scrubber) }
        }

        SentrySDK.setUser(User(userId: installationID))

        lock.lock()
        defer { lock.unlock() }
        activeFlag = true
    }

    func setConsent(_ consent: AppSettings.CrashReportingConsent) {
        if consent == .denied {
            guard isActive else { return }
            SentrySDK.flush(timeout: 2)
            SentrySDK.close()
            lock.lock()
            defer { lock.unlock() }
            activeFlag = false
        } else {
            start(consent: consent)
        }
    }

    // MARK: - Capture

    func capture(_ error: Error, context: [String: String]?) {
        guard isActive else { return }
        SentrySDK.capture(error: error) { scope in
            if let context, !context.isEmpty {
                scope.setContext(value: context, key: "operation")
            }
        }
    }

    func addBreadcrumb(category: String, message: String, level: CrashReportingLevel) {
        guard isActive else { return }
        let crumb = Breadcrumb(level: level.sentryLevel, category: category)
        crumb.message = scrubber.redact(message)
        SentrySDK.addBreadcrumb(crumb)
    }

    func flush(timeout: TimeInterval) async {
        guard isActive else { return }
        // SentrySDK.flush is blocking; hop off the main actor so terminate() is never stalled.
        // Task.detached is intentional here: we are escaping the caller's actor for a blocking call.
        await Task.detached(priority: .utility) {
            SentrySDK.flush(timeout: timeout)
        }.value
    }

    // MARK: - Configuration

    private static var releaseName: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "dev.zaphkiel.adbstudio"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return "\(bundleId)@\(version)"
    }

    private static var dist: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    private static var environment: String {
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    // MARK: - DSN resolution

    /// Resolved DSN: dev override (`SENTRY_DSN_OVERRIDE` in `UserDefaults`) first, then the
    /// build-injected `Info.plist` `SENTRY_DSN`. `nil` if blank — telemetry then stays inert.
    /// Never hard-coded in source (see security.md).
    private static var resolvedDSN: String? {
        let override = UserDefaults.standard.string(forKey: "SENTRY_DSN_OVERRIDE")
        let baked = Bundle.main.infoDictionary?["SENTRY_DSN"] as? String
        let resolved = (override ?? baked)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (resolved?.isEmpty == false) ? resolved : nil
    }

    /// Hosts the DSN may point at: Sentry SaaS plus the self-hosted host injected at build time
    /// (`SENTRY_ALLOWED_HOST`). Suffix matching covers regional ingest subdomains. Mirrors the
    /// allowlist pattern in `UpdateService.isDownloadURLTrusted`.
    private static var allowedHosts: Set<String> {
        var hosts: Set<String> = ["sentry.io"]
        if let custom = (Bundle.main.infoDictionary?["SENTRY_ALLOWED_HOST"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            hosts.insert(custom.lowercased())
        }
        return hosts
    }

    /// Validates the DSN's host against ``allowedHosts`` before the SDK is allowed to start.
    private static func isTrustedDSN(_ dsn: String) -> Bool {
        guard let host = URL(string: dsn)?.host?.lowercased() else { return false }
        return allowedHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    // MARK: - Scrubbing

    private static func scrub(_ event: Event, with scrubber: PIIScrubber) -> Event {
        // The macOS host name frequently embeds the user's real name.
        event.serverName = nil

        if let formatted = event.message?.formatted {
            event.message = SentryMessage(formatted: scrubber.redact(formatted))
        }

        event.exceptions?.forEach { exception in
            if let value = exception.value {
                exception.value = scrubber.redact(value)
            }
            scrubFrames(exception.stacktrace?.frames, with: scrubber)
        }
        event.threads?.forEach { thread in
            scrubFrames(thread.stacktrace?.frames, with: scrubber)
        }

        if let tags = event.tags {
            event.tags = tags.mapValues { scrubber.redact($0) }
        }
        if let extra = event.extra {
            event.extra = scrubber.redact(extra)
        }
        if let breadcrumbs = event.breadcrumbs {
            event.breadcrumbs = breadcrumbs.compactMap { scrub($0, with: scrubber) }
        }
        // Auto-attached contexts (e.g. context.device.name = the Mac's name, often the real user name).
        if let context = event.context {
            event.context = context.mapValues { scrubber.redact($0) }
        }
        return event
    }

    private static func scrub(_ span: Span, with scrubber: PIIScrubber) -> Span {
        span.operation = scrubber.redact(span.operation)
        if let description = span.spanDescription {
            span.spanDescription = scrubber.redact(description)
        }
        return span
    }

    private static func scrub(_ crumb: Breadcrumb, with scrubber: PIIScrubber) -> Breadcrumb? {
        // Clipboard breadcrumbs may carry user content — drop them entirely.
        if crumb.category.lowercased().contains("clipboard") {
            return nil
        }
        if let message = crumb.message {
            crumb.message = scrubber.redact(message)
        }
        if let data = crumb.data {
            crumb.data = scrubber.redact(data)
        }
        return crumb
    }

    private static func scrubFrames(_ frames: [Frame]?, with scrubber: PIIScrubber) {
        frames?.forEach { frame in
            if let fileName = frame.fileName {
                frame.fileName = scrubber.redact(fileName)
            }
            if let package = frame.package {
                frame.package = scrubber.redact(package)
            }
        }
    }
}

private extension CrashReportingLevel {
    var sentryLevel: SentryLevel {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .fatal: return .fatal
        }
    }
}
