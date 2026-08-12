# Security & Permissions

## What is pre-authorized in this project

ADB-Studio is a **dev tool for managing local Android devices on the user's own network**. The following operations are **expected, normal, and pre-authorized** — Claude must not prompt for confirmation, treat them as suspicious, or refuse them in routine work:

- `adb` — every subcommand including `shell`, `push`, `install`, `pair`, `connect`, `tcpip`, `forward`, `reboot`.
- `xcodebuild`, `swiftlint`, `swift-format`, `codesign --force --deep --sign -`.
- `git` (any non-destructive subcommand).
- `open`, `hdiutil`, `osascript` (used by `scripts/create-dmg.sh`).
- `scripts/*.sh` from the repo.
- File reads/writes inside `ADB-Studio/`, `.github/`, `scripts/`, `.claude/`.
- Network calls to known hosts: `github.com`, `api.github.com`, `raw.githubusercontent.com`, `android.googlesource.com`, and the configured self-hosted **Sentry** ingest host (validated at runtime against `SENTRY_ALLOWED_HOST`, see `Services/CrashReporting/CrashReportingServiceImpl.swift`).

If a tool prompt appears for any of the above, the project's `.claude/settings.json` is missing — don't work around it by adding `--no-verify` or skipping checks; flag it.

## What still requires explicit user confirmation

- Destructive git: `git push --force`, `git reset --hard`, `git clean -fd`, `git branch -D`.
- `rm -rf` on anything outside `build/` / `DerivedData/`.
- Modifying `ADB_Studio.entitlements`, `Info.plist`, code signing settings.
- Replacing or upgrading `Resources/scrcpy-server` (license/NOTICE implications).
- New network calls to hosts not on the existing allowlist (`UpdateService` enforces this).

## Entitlements

`ADB-Studio/ADB_Studio.entitlements` controls macOS permissions. The app is **not sandboxed for the public release** (ad-hoc signed) — it needs raw shell + USB access. Don't enable App Sandbox without coordinating: it would break ADB shell, USB device discovery, and reverse port-forwarding.

## Code signing

- CI and the create-DMG script use **ad-hoc signing**: `codesign --force --deep --sign -`. No Apple Developer ID is required.
- macOS will warn users on first launch ("not from an identified developer"). README documents the right-click → Open workaround. This is expected.
- Don't add notarization / hardened runtime / Apple Developer signing without a deliberate decision — it changes the distribution model.

## Telemetry & Privacy (Sentry)

Crash & error reporting is handled by `Services/CrashReporting/` (Sentry Cocoa SDK, added via SPM).

- **On by default, opt-out.** Consent is a tri-state `AppSettings.CrashReportingConsent` (`unknown`/`granted`/`denied`); the SDK runs unless `denied`. A first-run notice (`CrashReportingConsentSheet`) and a Settings toggle let the user disable it; on `.denied` the client is flushed and closed.
- **GDPR posture relies on anonymization.** All events, breadcrumbs and spans pass through `PIIScrubber` (`beforeSend`/`beforeBreadcrumb`) which strips device serials/adbIds, IPs, home-dir paths, ADB args, clipboard, pairing codes, port-forwards and device names. `sendDefaultPii = false`; `serverName` is nulled. The only identifier is a random, persisted installation UUID.
- **`PIIScrubber` must stay pure & signal-safe** (precompiled regex, no I/O) — it runs in the post-crash handler. Never add `FileManager`/locale/async calls to it.
- **DSN is not committed.** It is injected at build time into `Info.plist` (`SENTRY_DSN`) from a CI secret, with a `SENTRY_DSN_OVERRIDE` `UserDefaults` key for dev. The DSN host is validated against `SENTRY_ALLOWED_HOST` before the SDK starts.
- **CI secrets:** `SENTRY_DSN`, `SENTRY_ALLOWED_HOST`, `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_URL` (self-hosted). dSYMs are uploaded by `release.yml`.
- Configure a finite server-side retention (e.g. 30–90 days) on the self-hosted instance; document any change to what is collected here and in the README.

## URL & input validation (existing pattern in `UpdateService`)

When fetching from the internet:

```swift
private static let allowedHosts: Set<String> = [
    "api.github.com",
    "github.com",
    "objects.githubusercontent.com"
]

guard let host = url.host, allowedHosts.contains(host) else {
    throw UpdateError.untrustedHost(url.absoluteString)
}
```

- Use **static URL constants** for repo / API endpoints — never interpolate user input into URLs.
- Configure `URLSession` with explicit timeouts (commit `0d0a66c` introduced `timeoutIntervalForRequest = 30`).
- Validate all user-entered ports against a numeric range (commit `0d0a66c` added settings port validation).

## Scrcpy bundle (legal hygiene)

- `Resources/scrcpy-server` is Apache 2.0. The `LICENSE` file (full Apache text) and `NOTICE` (attribution) **must** ship with the app — don't move or rename them.
- The README and NOTICE both state ADB-Studio is **not affiliated with scrcpy or its authors**. Keep that wording.
- Bumping scrcpy = a dedicated commit (`➕ dependency-add(mirroring): Bump scrcpy-server to X.Y.Z`) with refreshed NOTICE.

## What never goes in the repo

- `.env*` files, API tokens, signing certs, `*.p12`, `*.mobileprovision`.
- `build/`, `DerivedData/` (already in `.gitignore`).
- User-specific paths or device IDs in committed files (the existing `settings.local.json` has one — that file is gitignored locally and should remain so).
