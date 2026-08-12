# Concurrency

The project is fully on Swift Concurrency (`async`/`await`, `Task`, actors). New code must follow the patterns below — copy from the cited file rather than inventing.

## Pattern: polling loop with cancellation

```swift
func startMonitoring() {
    autoRefreshTask?.cancel()
    autoRefreshTask = Task {
        await checkADBAvailability()
        await ensureServerRunning()
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(refreshInterval))
        }
    }
}

func stopMonitoring() {
    autoRefreshTask?.cancel()
    autoRefreshTask = nil
}
```

Source: `Services/Device/DeviceManager.swift:34-57`. Always store the `Task` in a property so it can be cancelled. Always `cancel()` the previous one before creating a new one.

## Pattern: parallel fetch with `withTaskGroup`

```swift
newDevices = await withTaskGroup(of: (Int, Device).self) { group in
    for (index, device) in newDevices.enumerated() {
        group.addTask {
            let full = await self.deviceIdentifier.fetchDeviceProperties(for: device)
            return (index, full)
        }
    }
    var results = newDevices
    for await (index, device) in group {
        results[index] = device
    }
    return results
}
```

Source: `Services/Device/DeviceManager.swift:76-90`. Preserve order via `(index, value)` tuples when the result must align with the input slice.

## Pattern: debounce

```swift
@Published var searchText = "" { didSet { debounceSearch() } }
private var searchDebounceTask: Task<Void, Never>?

private func debounceSearch() {
    searchDebounceTask?.cancel()
    searchDebounceTask = Task {
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }
        debouncedSearchText = searchText
        updateFilteredApps()
    }
}
```

Source: `ViewModels/InstalledAppsViewModel.swift`. Always cancel + sleep + check `isCancelled` after the sleep.

## Pattern: hopping back to MainActor from `nonisolated`

```swift
nonisolated func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    Task { @MainActor in
        if let container { await container.shutdown() }
        NSApplication.shared.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
}
```

Source: `App/ADB_StudioApp.swift:64-72`. Use this only when the framework requires `nonisolated` (delegate methods, completion handlers).

## Pattern: progress callbacks

For long-running work that needs incremental updates:

```swift
func installAPK(
    path: URL,
    deviceId: String,
    onStart: @escaping (APKInstallHandle) -> Void,
    onProgress: @escaping (String) -> Void
) async throws
```

Source: `Services/ADB/ADBService.swift:30`. The handle (`APKInstallHandle`) lets the caller cancel mid-flight; progress closures must tolerate being called from non-main contexts (mark them `@Sendable` if the impl crosses actor boundaries).

## `@unchecked Sendable` + NSLock

Only when you must share mutable state across threads and cannot use an actor:

```swift
final class APKInstallHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var _process: Process?

    func setProcess(_ process: Process) {
        lock.lock(); defer { lock.unlock() }
        _process = process
    }
}
```

Source: `Services/ADB/ADBService.swift:56-72`. Always use `lock(); defer { unlock() }`. Never expose the locked state directly.

## Forbidden / discouraged

- New `DispatchQueue.main.async { … }` — use `await MainActor.run` or rely on `@MainActor` isolation.
- New `Combine.sink` chains for I/O — use `for await` or `async` calls.
- `Task.detached` — only with a documented reason (escaping the current actor for cancellation isolation). Default to `Task { … }`.
- Sleeping with `usleep` / `sleep()` — use `try? await Task.sleep(for: .seconds(n))`.
- Capturing `self` strongly inside long-lived `Task`s without weak capture, when the closure outlives the owner.

## Cancellation hygiene

- Every long-lived `Task` is stored in a property and cancelled in the owner's deinit / `shutdown()` / `stop*()` method.
- `MirroringManager.stopAll()` is awaited from `DependencyContainer.shutdown()` — follow that precedent for new background work.
