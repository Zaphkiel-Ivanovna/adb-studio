# Architecture

## Layers

```
ADB_StudioApp (entry, scenes, commands)
   └── DependencyContainer (single source of dependencies, @MainActor)
         ├── *Store         (UserDefaults wrappers — SettingsStore, DeviceHistoryStore)
         ├── *Service / *ServiceImpl  (side-effecting boundaries — ADB, Shell, Screenshot, Update)
         ├── *Manager       (stateful coordinators — DeviceManager, MirroringManager, DeviceDiscoveryService)
         └── *ViewModel     (per-screen state — created on demand by Views)
                           ↓
                       Views (SwiftUI, .environmentObject)
```

## Folder layout (do not deviate)

```
ADB-Studio/
├── App/                  ADB_StudioApp.swift, DependencyContainer.swift
├── Models/               Plain data: Device, AppSettings, *Error, *History, …
├── Services/<Domain>/    Side-effects + coordination, grouped by domain
│   ├── ADB/              ADBService(.swift) + ADBServiceImpl + ADBOutputParser
│   ├── Device/           DeviceManager, DeviceIdentifier
│   ├── Discovery/        DeviceDiscoveryService
│   ├── Media/            ScreenshotService
│   ├── Mirroring/        Sub-modules: Server/, Network/, Media/, Input/, Protocol/
│   ├── Persistence/      *Store
│   ├── Shell/            ShellExecutor (+ ShellExecuting protocol)
│   └── Updates/          UpdateService, GitHubRelease
├── ViewModels/           Per-screen @MainActor classes
├── Views/<Feature>/      SwiftUI views, sheets, sections grouped by feature
├── Resources/            Bundled binaries (scrcpy-server) + licenses — never modify
└── Assets.xcassets/      App icon, colors
```

## When to introduce a sub-module under `Services/<Domain>/`

Create a sub-folder (e.g. `Services/Mirroring/Network/`) only when **all** are true:

- The domain has ≥ 5 files.
- The files split cleanly into orthogonal concerns (transport vs. decoding vs. protocol parsing).
- A new contributor would otherwise need a map. Refer to `Services/Mirroring/` for the precedent (`Server/`, `Network/`, `Media/`, `Input/`, `Protocol/`).

For 1–4 files, keep them flat inside `Services/<Domain>/`.

## Dependency Injection rules

- **One** `DependencyContainer`, owned by `ADB_StudioApp` via `@StateObject`.
- All long-lived dependencies are stored on the container. Order of init matches dependency order (see `DependencyContainer.init()` lines 19–37 — Store → Shell → ADB → Identifier → Manager …).
- Propagate via `.environmentObject(container)` plus targeted `.environmentObject(container.deviceManager)` / `.environmentObject(container.mirroringManager)` for high-traffic objects.
- Views consume via `@EnvironmentObject`, never `@StateObject` for shared services.
- ViewModels are `@StateObject` at their owning view; their dependencies are passed by init from `@EnvironmentObject` — see how `DeviceDetailView` constructs `DeviceDetailViewModel`.
- **No singletons.** No `*.shared`. If you find one, treat it as a bug.

## Lifecycle hooks (already implemented, reuse them)

- `container.start()` — kicks off monitoring + update check on app launch.
- `container.stop()` — pauses device polling.
- `container.shutdown() async` — graceful shutdown invoked from `ADBStudioAppDelegate.applicationShouldTerminate`. Awaits `mirroringManager.stopAll()`.

If you add a new long-running task, register its teardown in `shutdown()`.

## Cross-component communication

- Prefer **direct method calls** between Managers when one owns the other's reference (`MirroringManager` was init-ed with `deviceManager`).
- Use `NotificationCenter` only for **decoupled UI events** (e.g. `Notification.Name.showWiFiConnectionSheet` — declared in `ADB_StudioApp.swift`). Add new names in the same `extension Notification.Name` block.
- No new Combine `@Published` chains across files; prefer `await` calls.
