---
name: new-view
description: Scaffold a new SwiftUI View in ADB-Studio following the project's @MainActor/@EnvironmentObject conventions. Creates Views/<Feature>/<Name>View.swift, with optional companion files (<Name>Row.swift, <Name>Sheet.swift, <Name>Section.swift). Use when the user says "new view", "/new-view", or "scaffold view".
disable-model-invocation: true
---

# /new-view

User-invocable skill that scaffolds a SwiftUI view (or companion view) following ADB-Studio conventions.

## Usage

`/new-view <Feature> <Name> [Kind]`

- `<Feature>` — folder under `ADB-Studio/Views/` (e.g. `DeviceList`, `Mirroring`, `Settings`). Create it if missing.
- `<Name>` — base name (without suffix).
- `[Kind]` — optional: `View` (default) | `Row` | `Sheet` | `Section` | `Toolbar` | `StatusBar` | `Overlay`.

Examples:
- `/new-view InstalledApps AppFilter Section`
- `/new-view Mirroring Recording Toolbar`
- `/new-view Connection BluetoothPairing Sheet`

## What you must do

1. **Validate inputs.** If `<Feature>` and `<Name>` are missing, ask. Default `[Kind]` to `View` if absent.
2. **Read first** (mandatory):
   - `.claude/rules/swiftui-patterns.md`
   - `.claude/rules/naming-conventions.md`
   - One existing example matching the requested kind:
     - `View` → `ADB-Studio/Views/Main/ContentView.swift` or `Views/InstalledApps/InstalledAppsView.swift`
     - `Row` → `ADB-Studio/Views/DeviceList/DeviceRowView.swift`
     - `Sheet` → `ADB-Studio/Views/Connection/WiFiConnectionSheet.swift`
     - `Section` → `ADB-Studio/Views/DeviceDetail/DeviceInfoSection.swift`
     - `Toolbar`, `StatusBar`, `Overlay` → `Views/Mirroring/Mirroring{Toolbar,StatusBar,ShortcutsOverlay}.swift`
3. **Check for collisions.** `ls ADB-Studio/Views/<Feature>/` — if a similarly named file exists, stop and ask whether to extend it.
4. **Pick the file name.** `<Name><Kind>.swift` where Kind appends to the base — e.g. `BluetoothPairingSheet.swift`. For default `View`, file is `<Name>View.swift`.
5. **Generate the file** matching the kind's template:

### `View` template
```swift
import SwiftUI

struct <Name>View: View {
    @EnvironmentObject private var deviceManager: DeviceManager

    var body: some View {
        VStack {
            Text("<Name>View")
        }
    }
}
```

### `Row` template
```swift
import SwiftUI

struct <Name>Row: View {
    let item: <ItemType>  // TODO: replace with actual type

    var body: some View {
        HStack {
            Text(String(describing: item))
        }
    }
}
```

### `Sheet` template
```swift
import SwiftUI

struct <Name>Sheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        VStack(spacing: 16) {
            Text("<Name>")
                .font(.headline)

            // TODO: content

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 420)
    }
}
```

### `Section` template
```swift
import SwiftUI

struct <Name>Section: View {
    var body: some View {
        Section("<Name>") {
            // TODO: rows
        }
    }
}
```

### `Toolbar` / `StatusBar` / `Overlay` templates
Match the structure in `Views/Mirroring/Mirroring{Toolbar,StatusBar,ShortcutsOverlay}.swift` — small `HStack`/`ZStack` wrappers tied to a `MirroringSession` via `@ObservedObject`.

6. **Create the file**, then list the file path so the user can drag it into Xcode.
7. **Manual Xcode step:** Tell the user to drag the new file into Xcode under `Views/<Feature>/`. The skill cannot reliably edit `project.pbxproj`.
8. **No business logic.** Don't invent ViewModel wiring beyond an `@EnvironmentObject` placeholder. The user fills in domain types.

## Output

```
✅ Created ADB-Studio/Views/<Feature>/<FileName>.swift
⚠️  Manual step: drag the file into Xcode under the Views/<Feature> group.

Next: replace the TODOs and wire the relevant @EnvironmentObject / @StateObject.
```

## Rules

- Honor `.claude/rules/swiftui-patterns.md` (state ownership) and `.claude/rules/naming-conventions.md` (suffixes).
- Never use `@ObservedObject` for an object you create inside the view.
- Never use `@StateObject` for a shared service (use `@EnvironmentObject`).
- Do not import `Combine` in new views.
