---
name: new-service
description: Scaffold a new Service in ADB-Studio following the project's protocol+impl convention. Creates Services/<Domain>/<Name>Service.swift (protocol) plus <Name>ServiceImpl.swift, and registers the impl in DependencyContainer.swift. Use when the user says "new service", "/new-service", or "scaffold service".
disable-model-invocation: true
---

# /new-service

User-invocable skill that scaffolds a new Service following ADB-Studio conventions.

## Usage

`/new-service <Domain> <Name>` — e.g. `/new-service Notifications Push`, `/new-service Media VideoEncoding`.

## What you must do

1. **Validate inputs.** If the user didn't pass `<Domain>` and `<Name>`, ask once. Don't guess.
2. **Read first** (mandatory):
   - `.claude/rules/services.md`
   - `.claude/rules/naming-conventions.md`
   - `ADB-Studio/Services/ADB/ADBService.swift` (canonical protocol exemplar — note the `// MARK: -` groupings)
   - `ADB-Studio/App/DependencyContainer.swift` (to register the new service)
3. **Check for collisions.** `ls ADB-Studio/Services/<Domain>/` — if the folder exists with files of similar name, stop and ask the user whether to extend the existing service instead. The project rules forbid duplicate conventions.
4. **Create the protocol file** at `ADB-Studio/Services/<Domain>/<Name>Service.swift`:
   ```swift
   import Foundation

   protocol <Name>Service {
       // TODO: Add async throws methods. Example:
       // func list() async throws -> [<Name>Item]
   }
   ```
5. **Create the impl file** at `ADB-Studio/Services/<Domain>/<Name>ServiceImpl.swift`:
   ```swift
   import Foundation

   final class <Name>ServiceImpl: <Name>Service {
       // TODO: Inject dependencies via init.
       init() {}
   }
   ```
   - If the service needs `ShellExecuting`, `ADBService`, `SettingsStore`, etc., inject them as `init` parameters and store as `private let`. Mirror the constructor signature of `ADBServiceImpl`.
6. **Register in `DependencyContainer.swift`:**
   - Add the property: `let <name>Service: <Name>ServiceImpl` (lower-camel-case property, in the existing alphabetical-ish order block).
   - Initialize in `init()` after its dependencies (mirror the order around `adbService`, `screenshotService`).
   - If the service needs lifecycle teardown, add it to `shutdown()`.
7. **Add the .swift files to the Xcode project.** Modifying `ADB-Studio.xcodeproj/project.pbxproj` directly is fragile — instead **explicitly tell the user** to drag the two new files into Xcode under the right group (`Services/<Domain>`) so Xcode adds them to the build. Show the exact paths.
8. **Run the post-edit hook output** that fired automatically (swift-format + SwiftLint). Surface any warnings.
9. **Do NOT** invent method bodies, parsers, or test coverage. The skill creates the skeleton; implementation is a follow-up task.

## Output

End with a checklist:

```
✅ Created ADB-Studio/Services/<Domain>/<Name>Service.swift
✅ Created ADB-Studio/Services/<Domain>/<Name>ServiceImpl.swift
✅ Registered in DependencyContainer.swift (property + init)
⚠️  Manual step: drag both files into Xcode under Services/<Domain> group.

Next: define the protocol surface in <Name>Service.swift, then implement in <Name>ServiceImpl.swift.
```

## Rules

- Honor `.claude/rules/services.md` — protocol+impl split is the default.
- Honor `.claude/rules/naming-conventions.md` — `*Service` / `*ServiceImpl` only.
- Never create a `*.shared` singleton. Never inject `URLSession.shared` without a configured timeout.
- If `<Name>` ends in `Service` already, strip it before generating filenames.
- If `<Domain>` doesn't exist as a folder, create it.
