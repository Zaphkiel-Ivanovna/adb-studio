# Naming Conventions

## File suffixes (mandatory — pick the right one before creating a file)

| Suffix | Purpose | Examples |
|--------|---------|----------|
| `*Service` | Protocol describing a side-effecting boundary | `ADBService`, `ScreenshotService`, `UpdateService` |
| `*ServiceImpl` | Concrete implementation of a `*Service` protocol (when split) | `ADBServiceImpl` |
| `*ing` | Protocol when the noun-protocol pair would collide with an impl class | `ShellExecuting` (impl: `ShellExecutor`) |
| `*Manager` | Stateful, `@MainActor`, `ObservableObject` coordinator | `DeviceManager`, `MirroringManager` |
| `*ViewModel` | Per-screen `@MainActor ObservableObject` | `DeviceDetailViewModel`, `InstalledAppsViewModel` |
| `*View` | SwiftUI screen / large composite | `DeviceListView`, `SettingsView`, `MirroringWindowView` |
| `*Row` | Single-row list cell | `DeviceRowView`, `InstalledAppRow` |
| `*Section` | Group of related controls inside a View | `DeviceInfoSection`, `TextInputSection` |
| `*Sheet` | Modal sheet | `WiFiConnectionSheet`, `AddPortSheet` |
| `*Toolbar` / `*StatusBar` / `*Overlay` | Window chrome components | `MirroringToolbar`, `MirroringStatusBar`, `MirroringShortcutsOverlay` |
| `*Store` | UserDefaults wrapper | `SettingsStore`, `DeviceHistoryStore` |
| `*Error` | `enum … : LocalizedError` | `ADBError`, `MirroringError` |
| `*Parser` | Stateless utility | `ADBOutputParser` |
| `*Mapper` / `*Throttle` | Pure helper struct/class | `CoordinateMapper`, `KeycodeMapper`, `PointerThrottle` |
| `*Handle` | Cancellable handle returned to a caller | `APKInstallHandle`, `ShellProcessHandle` |
| `*Launcher` | Builds and launches an external process | `ServerLauncher` |
| `*Transport` | Network / IPC channel | `SessionTransport` |
| `*Renderer` / `*Decoder` | Media pipeline | `SampleBufferRenderer`, `H264Decoder` |
| `*Accessor` | Bridge between SwiftUI and AppKit | `WindowAccessor` |

## Type-kind conventions

- **Models**: `struct`. `Identifiable` if it lives in a `List`/`ForEach`. `Codable` if persisted. Examples: `Device`, `AppSettings`, `DiscoveredDevice`.
- **Domain enums**: `enum Foo: String, CaseIterable` for UI-bound (Picker, segmented), `enum Foo: String, Codable` for persisted, plain `enum` for control flow. Add `displayName` / `systemImage` / `description` computed properties when the enum drives UI (see `RebootMode` in `ADBService.swift:86-122`).
- **Errors**: `enum *Error: LocalizedError` with associated values for context. Always provide `errorDescription`.
- **Services**: `protocol *Service` + `final class *ServiceImpl: *Service`. If only one impl exists and there's no test seam, you may keep a single `final class`.
- **Managers / ViewModels**: `@MainActor final class … : ObservableObject`.
- **Helpers**: `struct` if value-type, `final class` if it owns mutable state.

## Identifier naming

- Variables, methods, parameters: `lowerCamelCase`.
- Types, protocols, enum cases: `UpperCamelCase`.
- Acronyms preserved as-is when conventional in the project: `ADB`, `URL`, `IP`, `TCP`, `APK`, `FPS`. Examples: `bestAdbId` (lowercase boundary), `isADBAvailable`, `ipAddress`, `apkInstallHandle`.
- Booleans: `is*`, `has*`, `should*`, `can*` — `isRefreshing`, `hasCheckedADB`, `isStartingServer`.
- Async-state pairs: `isXing` for in-flight, `xResult` / `lastX*` for result. See `DeviceDetailViewModel` (`isInstallingAPK`, `apkInstallProgress`, `apkInstallResult`).

## Sectioning inside a file

Use `// MARK: - Section Name` to group methods. One blank line before, one after.

```swift
// MARK: - Power Actions
func requestReboot(mode: RebootMode) { … }
func confirmReboot() async { … }

// MARK: - APK Install
func installAPK(url: URL) { … }
```

## Forbidden

- Generic suffixes: `*Helper`, `*Util`, `*Utils`, `*Tool` (no precedent in the codebase).
- Plural type names (`Devices`, `Apps`) — use the singular and store collections as `[Device]`.
- Hungarian prefixes (`mDevice`, `g_*`).
- Snake_case identifiers.
