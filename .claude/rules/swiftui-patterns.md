# SwiftUI & State Patterns

## State ownership rules

| Property wrapper | Use for | Example |
|------------------|---------|---------|
| `@StateObject` | The **first** instantiation of an `ObservableObject` (container, ViewModel) | `@StateObject private var container = DependencyContainer()` in `ADB_StudioApp` |
| `@EnvironmentObject` | Shared services injected via `.environmentObject(...)` | `DeviceManager`, `MirroringManager`, `DependencyContainer` |
| `@ObservedObject` | A child view receiving an already-owned object as a property | `MirroringRenderView(session:)` |
| `@Published` (inside an `ObservableObject`) | Mutable observable state | `@Published var devices: [Device] = []` |
| `@Published private(set)` | Read-only externally, mutated only from inside | `@Published private(set) var isRefreshing = false` (see `DeviceManager:7`) |
| `@State` | View-local UI scratch (selected tab, sheet flag, text field draft) | `@State private var showAddPortSheet = false` |
| `@Binding` | Two-way handle from a child to a parent's `@State` | Picker selection passed down |

## Manager / ViewModel template

```swift
import Foundation

@MainActor
final class FooManager: ObservableObject {
    @Published private(set) var items: [Foo] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: FooError?

    private let service: FooService
    private var refreshTask: Task<Void, Never>?

    init(service: FooService) {
        self.service = service
    }

    // MARK: - Public API
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await service.list()
            lastError = nil
        } catch let error as FooError {
            lastError = error
        } catch {
            lastError = .unknown(error.localizedDescription)
        }
    }
}
```

Mirrors `DeviceManager` (`Services/Device/DeviceManager.swift:1-90`) and `DeviceDetailViewModel`.

## View template

```swift
import SwiftUI

struct FooListView: View {
    @EnvironmentObject private var manager: FooManager
    @State private var selectedId: String?

    var body: some View {
        List(manager.items, selection: $selectedId) { item in
            FooRowView(item: item)
        }
        .task { await manager.refresh() }
        .refreshable { await manager.refresh() }
    }
}
```

## ViewModel-owning View

```swift
struct FooDetailView: View {
    @EnvironmentObject private var container: DependencyContainer
    @StateObject private var viewModel: FooDetailViewModel

    init(item: Foo, container: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: FooDetailViewModel(
            item: item,
            service: container.fooService
        ))
    }
    …
}
```

The `init` pattern with `_viewModel = StateObject(...)` is required because SwiftUI prohibits direct assignment to `@StateObject` from outside.

## Required practices

- Every `Manager` and `ViewModel` is `@MainActor final class`. No exceptions for "small" classes.
- Public mutable state is `@Published`. Public read-only state is `@Published private(set)`.
- Long-running work uses `async`/`await`, kicked off from `.task { … }` or `Task { … }` in an action handler.
- `MARK:` sections to group: Public API, Private helpers, Lifecycle, plus domain groups (`Power Actions`, `APK Install`, `Search & Filter`).
- For windowed UIs (`MirroringWindowView`), use `WindowGroup(id: …, for: String.self)` (see `ADB_StudioApp:46-52`) — not multiple `Window` declarations.

## Forbidden in new code

- New `Combine` chains (`Publisher.sink`, `.assign(to:)`). The existing `setupSettingsObserver` in `DependencyContainer` is the only legacy one — do not propagate the pattern.
- `DispatchQueue.main.async { … }` — replace with `await MainActor.run` or simply rely on `@MainActor` isolation.
- `@ObservedObject` on a property that was created inside the same view (use `@StateObject`).
- Force-unwrapping (`!`) of optionals — SwiftLint flags it; if you genuinely need it, document why in a single-line comment.
- `@State` for anything that should outlive the view's identity (use the container or a ViewModel).
