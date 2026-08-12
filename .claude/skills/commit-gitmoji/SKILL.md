---
name: commit-gitmoji
description: Generate and apply a git commit message in ADB-Studio's gitmoji format (EMOJI type(scope): subject + ' * ' bullets). Reads git status and git diff --staged, drafts a message, asks for confirmation, then commits. Use when the user says "/commit-gitmoji", "commit with gitmoji", or "make a project-style commit".
disable-model-invocation: true
---

# /commit-gitmoji

User-invocable skill that produces a commit message matching the project's gitmoji convention and runs `git commit` on the user's behalf.

## Usage

`/commit-gitmoji [optional hint]` — the optional hint is free text describing intent (e.g. "main change is the new Bluetooth pairing tab"). The skill picks it up to bias the headline.

## What you must do

1. **Read first**: `.claude/rules/git-workflow.md` (the canonical commit format and emoji table).
2. **Inspect the staged diff:**
   - `git status` (no `-uall`)
   - `git diff --staged`
   - `git log -5 --pretty=oneline` (to mirror recent style)
3. **Refuse if nothing is staged.** Don't auto-stage. Tell the user to `git add <paths>` and re-invoke.
4. **Refuse if a sensitive file is staged** (`.env*`, `*.p12`, `*.mobileprovision`, files in `build/`, files with `secret`/`token` in the path). Surface the file and ask.
5. **Compose the message:**
   - **Headline:** pick the dominant emoji + `type(scope): Subject in sentence case` from the table in `rules/git-workflow.md`.
   - **Body bullets:** one per logically distinct sub-change; format ` * EMOJI sub-type(scope): Detail`. Use the inline ` * ` convention (no Markdown lists).
   - Use scopes that already exist in `git log` when possible (`mirroring`, `wifi`, `pairing`, `discovery`, `adb`, `apk`, `apps`, `power`, `settings`, `sidebar`, `ui`, `tools`, `updates`, `ci`, `release`, `docs`, `config`, `xcode`, `assets`, `deps`).
   - Keep the headline under ~80 chars where possible.
6. **Show the proposed message to the user** and ask for confirmation. Don't commit without explicit go-ahead.
7. **On confirmation, commit using a HEREDOC** (preserves multi-line formatting):

```bash
git commit -m "$(cat <<'EOF'
<HEADLINE>
 * <BULLET 1>
 * <BULLET 2>
EOF
)"
```

Do **not** add a `Co-Authored-By:` trailer unless the user asks (the project's existing commits don't carry one).

8. **After committing,** run `git status` once and report success + the new commit hash.

## If the diff is mixed

If `git diff --staged` shows multiple unrelated concerns:

- Suggest splitting into multiple commits (each with its own headline).
- Offer the multi-commit plan as a numbered list; let the user choose.

## Hard rules

- Never run `git add` without explicit permission. Never `git add .` or `git add -A`.
- Never use `--no-verify`. If a hook fails, surface the failure and let the user fix it; create a new commit rather than amending.
- Never `--amend` a pushed commit.
- Never push.
- The `Co-Authored-By: Claude` trailer is **not** part of this project's convention — omit it.

## Output

```
Proposed commit:
─────────────────────────────────────
<headline>
 * <bullet 1>
 * <bullet 2>
─────────────────────────────────────

Files staged:
- path/foo.swift
- path/bar.swift

Reply "go" to commit, or amend the message above.
```

After commit:

```
✅ Committed <short-hash> on <branch>
```
