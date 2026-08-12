# Error Handling

## Domain error enums

Every domain that throws defines a single `enum *Error: LocalizedError`. Pattern from `Models/ADBError.swift`:

```swift
enum FooError: LocalizedError {
    case notFound(String)
    case operationFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Foo '\(id)' not found."
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .timeout:
            return "Operation timed out"
        }
    }
}
```

Rules:

- File name: `*Error.swift` in `Models/` (or alongside the service if the error type is purely internal — `Services/Mirroring/MirroringError.swift`).
- Cases use associated `String` / typed values for context. Avoid throwing raw strings.
- `errorDescription` always returns a complete English sentence with punctuation.
- Add new cases at the end of the existing enum; don't fork a new error type for the same domain.

## Throwing boundaries

- Services throw domain errors. They are the throwing boundary.
- Managers / ViewModels catch and translate to UI state.

## Catch pattern (in Manager / ViewModel)

```swift
func enableTcpip(port: Int) async {
    do {
        try await adbService.enableTcpip(port: port, deviceId: device.bestAdbId)
        successMessage = "TCP/IP enabled on port \(port)"
    } catch let error as ADBError {
        errorMessage = error.localizedDescription
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

The double-catch is intentional: the typed catch lets you specialise per case if needed; the untyped catch is a safety net. Don't swallow errors silently — always set `errorMessage` (or equivalent) so the UI surfaces the failure.

## UI feedback

- `errorMessage: String?` and `successMessage: String?` are the standard ViewModel fields (see `DeviceDetailViewModel:16-17`).
- Auto-dismiss success after ~2s using a `Task` (existing `showSuccess` helper pattern).
- Don't show a SwiftUI `Alert` for every error; use inline status banners unless the error blocks navigation.

## Throw vs. log vs. return

| Situation | Action |
|-----------|--------|
| Caller can recover (retry, fallback, skip) | `throw` typed error |
| Programming error (invariant broken) | `assertionFailure` / `preconditionFailure` |
| Best-effort cleanup that fails harmlessly | swallow with `try?` and a one-line comment |
| Diagnostics-only signal | use `print` very sparingly; no logging framework yet |

## Forbidden

- `fatalError` in production paths.
- `try!` outside of compile-time-safe constants (SwiftLint warning is intentional).
- Throwing `NSError`. Always wrap in a domain error.
- `catch { }` (empty catch). At minimum, assign to `lastError` or `errorMessage`.
