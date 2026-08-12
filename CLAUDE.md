# ADB-Studio — Claude Code Rules

Native macOS SwiftUI app for managing Android devices over ADB. Mirroring is powered by a bundled `scrcpy-server` binary. Pure Xcode project, no SPM. Target: macOS 14+, arm64, Swift 5.x.

## Opus 4.7 Guardrails (read every turn)

1. **Confirm intent before coding.** Restate the goal in one line, then verify how the change fits the surrounding codebase. No silent assumptions.
2. **Reuse, never recreate.** Before adding a Service / View / Manager / error case, find the closest existing one (grep the suffix) and follow its shape. Never introduce a parallel convention.
3. **Read before you write.** Never assume an unread file's contents. If context is thin, say so and ask — do not improvise an implementation.
4. **Effort budget: normal by default.** Renames, field additions, small refactors, and UI tweaks use normal reasoning. Reserve deep reasoning for architecture decisions and non-obvious bugs.
5. **Dev ops are pre-authorized.** `xcodebuild`, `adb`, `swiftlint`, `swift-format`, `git`, `open`, `scripts/*`, edits inside `ADB-Studio/` — run them without asking. Only stop for destructive ops (force push, `rm -rf`, `git reset --hard`).
6. **Keep state on the main actor.** Every Manager / ViewModel is `@MainActor final class`. Use `async`/`await` for I/O, never new Combine chains.

## Required reading per task type

| Task | Read first |
|------|-----------|
| Add / change a Service | `.claude/rules/services.md` + `naming-conventions.md` |
| Add / change a View, Sheet, Section, Row | `.claude/rules/swiftui-patterns.md` + `naming-conventions.md` |
| Add / change a Manager or ViewModel | `.claude/rules/swiftui-patterns.md` + `architecture.md` |
| Touch `Services/Mirroring/**` | `.claude/rules/mirroring.md` |
| Add / change error types | `.claude/rules/error-handling.md` |
| Async / Task / threading work | `.claude/rules/concurrency.md` |
| Commits, branches, releases | `.claude/rules/git-workflow.md` |
| `xcodebuild`, CI, SwiftLint, swift-format | `.claude/rules/build-and-ci.md` |
| Entitlements, signing, scrcpy bundle | `.claude/rules/security.md` |
| Folder layout, DI wiring | `.claude/rules/architecture.md` |

## Canonical exemplars (cite these, don't invent new patterns)

- DI: `ADB-Studio/App/DependencyContainer.swift`
- Service protocol/impl: `ADB-Studio/Services/ADB/ADBService.swift` + `ADBServiceImpl.swift`
- Manager: `ADB-Studio/Services/Device/DeviceManager.swift`
- ViewModel: `ADB-Studio/ViewModels/DeviceDetailViewModel.swift`
- State machine: `ADB-Studio/Services/Mirroring/MirroringSession.swift`
- Error enum: `ADB-Studio/Models/ADBError.swift`

## Reflexes

- Before suggesting a new file, run a suffix grep (`*Service`, `*Manager`, `*View`) to confirm nothing equivalent exists.
- Before importing a framework, check what `ADB_StudioApp.swift` and `DependencyContainer.swift` already pull in.
- Before writing concurrency code, mirror an existing pattern (`startMonitoring` for polling, `withTaskGroup` for parallel fetch, `Task.sleep` + cancel for debounce).
- For commits: gitmoji + scope, body bullets joined by ` * ` — see `.claude/rules/git-workflow.md`.
- All Swift edits go through the post-edit hook (swift-format then SwiftLint). If the hook complains, fix the cause — do not bypass.
