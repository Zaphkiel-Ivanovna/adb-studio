# Build & CI

## Local build commands

```bash
# Debug build (used for daily dev + CI)
xcodebuild -scheme "ADB-Studio" \
  -configuration Debug \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath build \
  clean build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# Release build (what the release.yml workflow runs before signing & packaging)
xcodebuild -scheme "ADB-Studio" \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath build \
  clean build
```

Open the Xcode project: `open ADB-Studio.xcodeproj`. There is no `Package.swift` — this is a pure Xcode project.

## Targets / SDK

- Single target: **ADB-Studio**.
- Deployment target: **macOS 14.0** (Sonoma) — see `MACOSX_DEPLOYMENT_TARGET` in the project. Don't raise/lower without an explicit decision.
- Architecture: **arm64** (Apple Silicon). Intel is not in scope.
- Swift language version: **5**. Whole-module compilation in Release.

## Lint / format

```bash
# Format (project enforces in CI)
swift-format lint --recursive ADB-Studio/
swift-format -i <files>     # in-place fix (used by the post-edit hook)

# Lint
swiftlint lint
swiftlint lint --quiet --path <file>    # used by the post-edit hook
```

`.swiftlint.yml` highlights:

- **Disabled** (deliberately permissive): `trailing_whitespace`, `line_length`, `identifier_name`, `type_name`, `function_body_length`, `file_length`, `cyclomatic_complexity`, `nesting`.
- **Opt-in** (must pass): `empty_count`, `empty_string`, `closure_spacing`, `contains_over_first_not_nil`, `discouraged_optional_boolean`, `fallthrough`, `first_where`, `force_unwrapping`, `implicitly_unwrapped_optional`, `last_where`, `modifier_order`, `overridden_super_call`, `private_action`, `private_outlet`, `redundant_nil_coalescing`, `sorted_first_last`, `toggle_bool`, `unavailable_function`, `unneeded_parentheses_in_closure_argument`, `vertical_parameter_alignment_on_call`, `yoda_condition`.
- `force_cast` and `force_try` are warnings — use sparingly, never in new code without a comment.

Use `Bool?` is **discouraged** (`discouraged_optional_boolean`) — model with an enum instead.

## Post-edit hook

`.claude/settings.json` runs swift-format + SwiftLint on every Edit/Write of a `.swift` file. Output goes back to Claude. If the hook flags an issue, fix the cause; don't bypass.

## CI (`.github/workflows/ci.yml`)

Triggers on push / PR to `main` (and `develop` if it exists). Runner: `macos-26`, Xcode `26.0`.

Three jobs:

1. **🔨 Build & Test** — `xcodebuild build` then `xcodebuild test` (test step is `continue-on-error: true`, so build break is the real failure).
2. **🧹 SwiftLint** — `brew install swiftlint && swiftlint lint --reporter github-actions-logging` (non-blocking).
3. **📐 Swift Format Check** — `brew install swift-format && swift-format lint --recursive ADB-Studio/` (non-blocking).

The non-blocking jobs are aspirational; treat their warnings as TODOs.

## Tests

There is **no test target** as of now. If you add one:

- Target name: `ADB-StudioTests`.
- Framework: `XCTest` (or `Testing` with macOS 14+ adoption — match Xcode 26 defaults).
- Don't mock the file system or shell at the unit level for ADB code; integration via a fake `ShellExecuting` is the right seam (see `Services/Shell/ShellExecutor.swift`).

## Release (`.github/workflows/release.yml`)

Triggered by tags matching `v*`. Steps: build Release → ad-hoc sign (`codesign --force --deep --sign -`) → produce `.dmg` + `.zip` + SHA256 checksums → create GitHub Release → update Homebrew tap (skipped for `alpha|beta|rc` tags). Don't try to reproduce this locally for actual releases — let CI do it. `scripts/create-dmg.sh` exists for offline reference / debugging.

## Useful one-liners

```bash
# Show available schemes
xcodebuild -list -project ADB-Studio.xcodeproj

# Show resolved settings for the active config
xcodebuild -showBuildSettings -scheme "ADB-Studio" -configuration Debug | head -50

# Run a freshly built app
open build/Build/Products/Debug/ADB-Studio.app
```
