<!--
Thanks for contributing to ADB-Studio!
Please fill in every section that applies. Delete the ones that don't.
The HTML comments are guidance — they won't appear in the rendered PR.
-->

## Summary

<!--
1–3 lines. Mirror the commit headline format: `EMOJI type(scope): Subject in sentence case`.
Example: ✨ feat(mirroring): Add audio forwarding via scrcpy audio source.
See .claude/rules/git-workflow.md for the full emoji + scope table.
-->



## Type of change

<!-- Tick everything that applies. Headline emoji should match the dominant type. -->

- [ ] ✨ `feat` — new user-visible feature
- [ ] 🐛 `fix` — bug fix
- [ ] ♻️ `refactor` — restructure without behavior change
- [ ] 🏗️ `architecture` — new module / layer / DI rewiring
- [ ] 💄 `ui` — visual polish, layout, styling
- [ ] ⚡️ `performance` — speed / memory improvement
- [ ] 🥅 `error-handling` — new error cases, better diagnostics
- [ ] 🔧 `config` — project / build / runtime configuration
- [ ] 👷 `ci` — GitHub Actions / pipelines
- [ ] ➕ `dependency-add` — new dependency or bundled binary (e.g. scrcpy bump)
- [ ] 🔒️ `security` — hardening, validation, secrets handling
- [ ] 📝 `docs` — README, screenshots, in-repo docs

## Scope

<!--
One scope per PR if possible. Canonical scopes:
mirroring · wifi · pairing · discovery · adb · apk · apps · power · settings ·
sidebar · ui · tools · updates · ci · release · docs · config · xcode · assets · deps
-->

`scope-here`

## Motivation & context

<!--
Why does this change exist? What user-visible problem does it solve?
If it's driven by an issue, link it (Closes #123). If not, say so.
-->



## Implementation notes

<!--
Bullet list. Call out anything a reviewer should not miss:
- New files: which Service / Manager / ViewModel / View, and which canonical exemplar you followed (see CLAUDE.md → "Canonical exemplars").
- DI changes: any new property on `DependencyContainer` and its init order.
- New `Notification.Name`, `ServerParameters` field, error case, or AppSettings key.
- Concurrency: which pattern from `.claude/rules/concurrency.md` you mirrored.
- Anything intentionally out of scope.
-->

- 

## How to test

<!-- Manual test plan is REQUIRED — there is no automated test target yet. -->

**Environment**

- macOS: `<14.x / 15.x>`
- Xcode: `<26.x>`
- Android device(s): `<model> · Android <version> · USB | Wi-Fi`

**Steps**

1. 
2. 
3. 

**Expected result**

<!-- What should the user see / what state should the device end in? -->



**Edge cases verified**

<!-- Tick the ones you actually exercised. -->

- [ ] Device disconnect mid-flow (USB unplug or Wi-Fi drop)
- [ ] Multiple devices connected at once
- [ ] Wi-Fi pairing fallback path
- [ ] ADB server stopped → app recovers / restarts it
- [ ] App quit while session active (graceful shutdown via `DependencyContainer.shutdown()`)
- [ ] N/A — purely internal / non-runtime change

## Screenshots / Recordings

<!-- REQUIRED for any 💄 ui change. Drag-and-drop into the PR. Before/after side by side when relevant. -->



<details>
<summary>Mirroring impact (fill only if Services/Mirroring/** or Views/Mirroring/** changed)</summary>

<!-- See .claude/rules/mirroring.md before editing this subsystem. -->

- [ ] `MirroringSession` state machine invariants preserved (`idle → connecting → streaming` / `→ error` / `→ disconnected`).
- [ ] All long-running `Task`s stored in properties and cancelled on stop.
- [ ] `Resources/scrcpy-server`, `LICENSE`, `NOTICE` **not** modified — OR — this is an explicit scrcpy version bump with refreshed NOTICE and a dedicated `➕ dependency-add(mirroring)` commit.
- [ ] No inline scrcpy protocol parsing outside `Services/Mirroring/Protocol/**`.
- [ ] No hard-coded screen dimensions — `session.resolution` used instead.

</details>

## Pre-merge checklist

- [ ] `xcodebuild -scheme "ADB-Studio" -configuration Debug -destination "platform=macOS,arch=arm64" -derivedDataPath build clean build` passes locally.
- [ ] `swift-format lint --recursive ADB-Studio/` passes (or fixes applied via `swift-format -i`).
- [ ] `swiftlint lint` introduces no new warnings.
- [ ] Commits follow gitmoji + scope format (see `.claude/rules/git-workflow.md`).
- [ ] No new `DispatchQueue.main.async`, `Combine.sink`, force-unwrap (`!`), or `*.shared` singletons.
- [ ] Screenshots attached for any UI-visible change.
- [ ] Linked issue or explicit "N/A — direct change" in **Motivation & context**.

## Related issues

<!-- e.g. Closes #42 · Refs #17 -->

Closes #

<!--
Reminder: the CI SwiftLint and swift-format jobs are non-blocking (see .github/workflows/ci.yml),
but their warnings should still be fixed before merge.
-->
