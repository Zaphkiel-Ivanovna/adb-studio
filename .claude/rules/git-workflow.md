# Git Workflow

## Commit format (gitmoji + scope, mandatory)

```
EMOJI type(scope): Subject in sentence case
 * EMOJI sub-type(scope): Detail one
 * EMOJI sub-type(scope): Detail two
```

- The first line is the headline. The body bullets are joined inline with ` * ` (space-asterisk-space) — that's the project's actual style; no Markdown lists, no blank line between headline and bullets when shown via `git log --oneline`.
- Use the **headline** alone for trivial single-concern commits.
- For multi-concern commits, the headline summarizes the highest-level change; each ` * ` bullet covers one sub-change with its own emoji + type + scope.
- Sentence case (no period) for subjects.

### Real example from the repo

```
✨ feat(mirroring): Add screen mirroring and control via scrcpy
 * 🏗️ architecture: Introduce MirroringManager, MirroringSession and transport layer
 * ➕ dependency-add: Bundle scrcpy-server 3.3.4 binary and Apache 2.0 license
 * 💄 ui: Add MirroringWindowView, toolbar, status bar and shortcuts overlay
 * 🔧 config: Add mirroring settings to AppSettings with safe Codable defaults
 * 🛂 auth: Add NSApplicationDelegate for graceful async shutdown on quit
```

## Emoji table (use these, no others)

| Emoji | Type | When |
|-------|------|------|
| ✨ | `feat` | New user-visible feature |
| 🐛 | `fix` | Bug fix |
| ♻️ | `refactor` | Code restructure without behavior change |
| 🏗️ | `architecture` | Larger structural change (new module, new layer) |
| 💄 | `ui` / `style` | UI / visual polish |
| 🔧 | `config` | Project / build / runtime configuration |
| 📝 | `docs` | Documentation, README, screenshots |
| 👷 | `ci` | GitHub Actions / CI pipelines |
| 🔒️ | `security` | Hardening, validation, secrets handling |
| 🥅 | `error-handling` | New error cases / better diagnostics |
| ⚡️ | `performance` | Speed / memory improvement |
| 🦺 | `validation` | Input / data validation |
| 🍱 | `assets` | Icons, images, asset catalogs |
| 🔥 | `cleanup` | Remove dead code |
| 🧵 | `concurrency` | Threading / actor / async tweaks |
| ➕ | `dependency-add` | Adding an external dependency or bundled binary |
| ⬆️ | `bump` | Dependency or version bump |
| 🛂 | `auth` | Authentication / authorization / permissions |
| 🎨 | `style` | Code style / formatting |
| 🔨 | `dev-scripts` | Scripts under `scripts/` |
| 🎉 | `init` | Project / module bootstrap |

If your change doesn't fit a single emoji, pick the dominant one for the headline and split the sub-changes across bullets with their own emojis.

## Scopes (representative — match an existing one when possible)

`mirroring`, `wifi`, `pairing`, `discovery`, `adb`, `apk`, `apps`, `power`, `settings`, `sidebar`, `ui`, `tools`, `updates`, `ci`, `release`, `docs`, `config`, `xcode`, `assets`, `deps`.

## Branches

- `main` — protected, releases are tagged here.
- Feature branches: `feat/<short-slug>` (e.g. `feat/manage-apps`). Merge via PR.
- No `develop` branch. Dependabot PRs (`dependabot/github_actions/...`) auto-update CI actions.

## Releases

```bash
git tag -a v1.2.3 -m "Release 1.2.3"
git push origin v1.2.3
```

The `release.yml` workflow takes over: builds Release for `arm64`, ad-hoc signs, produces `.dmg` + `.zip` + `checksums.txt`, creates a GitHub Release (pre-release if tag contains `alpha|beta|rc`), and updates the Homebrew tap (skipped for pre-releases). Do not run `scripts/create-dmg.sh` manually for distribution — let CI do it.

## Pre-commit checklist (before staging)

1. `swift-format -i <touched files>` (or rely on the post-edit hook).
2. `swiftlint lint --quiet --path <touched files>` — fix all warnings you can.
3. Build: `xcodebuild -scheme ADB-Studio -configuration Debug -destination 'platform=macOS,arch=arm64' build`.
4. Stage **explicit file paths** — never `git add .` or `git add -A` (avoids committing `.DS_Store`, `build/`, accidental secrets).
5. Compose the commit using the format above. Use a HEREDOC if invoking `git commit -m`.

## Hard rules

- Never `git push --force` to `main`.
- Never amend a pushed commit.
- Never commit `.env*`, credentials, or `build/` artefacts.
- If a hook fails, fix the underlying issue and create a **new** commit — do not `--no-verify`.
