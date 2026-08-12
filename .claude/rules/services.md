# Services

A **Service** is a side-effecting boundary: it talks to ADB, the shell, the file system, the network, or scrcpy. Managers consume services; views never call services directly.

## When to split into protocol + impl

Split (`FooService` protocol + `FooServiceImpl` class) when **any** is true:

- The service is consumed by a `Manager` or `ViewModel` you might want to fake (most cases).
- The implementation is non-trivial (>50 lines or holds state).
- Multiple call-sites across the app.

If it is a small one-shot helper used in one place, you may keep a single `final class` — but err on the side of splitting; `ADBService` is the canonical reference (`Services/ADB/ADBService.swift`).

## Protocol style

```swift
protocol FooService {
    func list() async throws -> [Foo]
    func get(id: String) async throws -> Foo
    func update(_ foo: Foo) async throws
}
```

- Methods are `async throws` unless they cannot fail (`async`) or are pure synchronous queries (rare).
- No callbacks for new APIs **except** when reporting incremental progress that doesn't fit `AsyncSequence` — then use `@escaping` closures, see `installAPK(path:deviceId:onStart:onProgress:)` in `ADBService.swift:30`.
- Group related methods with `// MARK: -` inside the protocol body (see `// MARK: - App Management`, `// MARK: - Power Actions`, `// MARK: - Server Management` in `ADBService.swift`).
- Errors thrown are domain-specific (`ADBError`, `MirroringError`). Wrap lower-level errors at the boundary.

## Impl style

```swift
final class FooServiceImpl: FooService {
    private let shell: ShellExecuting
    private let settingsStore: SettingsStore

    init(shell: ShellExecuting, settingsStore: SettingsStore) {
        self.shell = shell
        self.settingsStore = settingsStore
    }

    func list() async throws -> [Foo] {
        let raw = try await shell.run(["adb", "list-foos"])
        return try FooParser.parse(raw)
    }
}
```

- Dependencies are injected via `init`. No `*.shared`.
- Parsing logic lives in a sibling `*Parser` (see `ADBOutputParser`). Keep services focused on orchestration.
- If the implementation needs background threading, mark the class `final` and use `@unchecked Sendable` only with explicit `NSLock` synchronization (see `APKInstallHandle` in `ADBService.swift:56-72`).

## Domain folders

```
Services/
├── ADB/        ADBService, ADBServiceImpl, ADBOutputParser
├── Device/     DeviceManager, DeviceIdentifier
├── Discovery/  DeviceDiscoveryService
├── Media/      ScreenshotService
├── Mirroring/  MirroringManager + sub-modules — see rules/mirroring.md
├── Persistence/SettingsStore, DeviceHistoryStore
├── Shell/      ShellExecutor + ShellExecuting protocol
└── Updates/    UpdateService, GitHubRelease (Codable model)
```

Add a new domain folder when you have a coherent set of services that share concepts (data types, lifecycle). Put a single isolated service at the matching existing domain when possible.

## Registration in DependencyContainer

Every service that needs to be reachable from views/managers is registered as a `let` property on `DependencyContainer`. Order in `init()` follows dependency order — see lines 19–37. Update `shutdown()` if your service holds resources that need teardown (`mirroringManager.stopAll()` is the precedent).

## Anti-patterns

- Service methods that mutate published `@MainActor` state directly. Services return data; the Manager applies it.
- Services with their own `@Published` properties — that's a Manager, not a Service. Move it.
- Calling `URLSession.shared` directly without a timeout. Configure `URLSession` like `UpdateService` does (see commit `0d0a66c`).
