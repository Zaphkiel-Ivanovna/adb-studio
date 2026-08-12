# Mirroring (scrcpy integration)

Mirroring is the most complex subsystem in the app. **Read this entire file before touching `Services/Mirroring/**` or `Views/Mirroring/**`.**

## Bundled binary — do not modify

- `ADB-Studio/Resources/scrcpy-server` — version **3.3.4**, Apache 2.0.
- `ADB-Studio/Resources/scrcpy-license/{LICENSE,NOTICE}` — Apache 2.0 license + NOTICE attributing Romain Vimont and the scrcpy contributors.
- **Never regenerate, rename, or replace these files** as part of routine work. Bumping scrcpy is a deliberate dependency upgrade — it gets its own commit (`➕ dependency-add(mirroring): Bump scrcpy-server to X.Y.Z`) and must be accompanied by a refreshed NOTICE.
- The app is **not affiliated with scrcpy** (per the NOTICE). Don't claim otherwise in UI/docs.

## Module map

```
Services/Mirroring/
├── MirroringManager.swift       Owns the per-device session pool. Public entry: startSession/stopSession/stopAll.
├── MirroringSession.swift       Per-device state machine. State enum: idle / connecting / streaming / disconnected / error(MirroringError).
├── MirroringError.swift         Domain errors.
├── Server/
│   ├── ServerLauncher.swift     Pushes & launches scrcpy-server via ADB; returns ServerLaunchResult.
│   └── ServerParameters.swift   Codable config (maxSize, maxFps, stayAwake, …); generateScid() for unique session IDs.
├── Network/
│   └── SessionTransport.swift   Reverse-tunnel + framed I/O. Sends ControlMessages, receives DeviceMessages + VideoPackets.
├── Media/
│   ├── H264Decoder.swift        VideoToolbox-backed decoder; emits CMSampleBuffers.
│   └── SampleBufferRenderer.swift  AppKit NSView wrapper exposed to SwiftUI via WindowAccessor.
├── Input/
│   ├── CoordinateMapper.swift   Maps SwiftUI/AppKit pointer space → device pixel coords (handles aspect ratio + rotation).
│   ├── KeycodeMapper.swift      macOS NSEvent.keyCode → Android KeyEvent codes.
│   └── PointerThrottle.swift    Coalesces pointer-move events to avoid flooding the device.
└── Protocol/
    ├── ControlMessage.swift     Outbound packets (touch, key, scroll, set-clipboard, …) with binary serialization.
    ├── DeviceMessage.swift      Inbound (clipboard, ack, UH-clipboard).
    ├── DeviceMeta.swift         Initial handshake (device name, codec, dimensions).
    └── VideoPacket.swift        Framed video chunks with PTS.
```

## Where to put new code

| Change | Goes in |
|--------|---------|
| New scrcpy launch parameter (e.g. `--audio-source`) | `ServerParameters` (add field + `Codable` default) + `ServerLauncher` (wire CLI flag) |
| New control message (gesture, sensor) | `Protocol/ControlMessage.swift` (new case + serialization) + `MirroringSession.send(...)` API + UI surface in `MirroringToolbar` or `MirroringRenderView` |
| Different video codec | `Media/` (new decoder), `Protocol/VideoPacket` parsing tweaks, `MirroringSession.codec` published state |
| Better pointer mapping | `Input/CoordinateMapper.swift` only — don't sprinkle math in the View |
| HUD / FPS / bitrate | `Views/Mirroring/MirroringStatusBar.swift` — `MirroringSession` already publishes `fps`, `bitrate`, `resolution` |
| Window chrome | `Views/Mirroring/MirroringToolbar.swift` / `MirroringShortcutsOverlay.swift` |

## Lifecycle invariants (read before refactoring)

- `MirroringManager` is `@MainActor final class` (`Services/Mirroring/MirroringManager.swift`).
- One `MirroringSession` per `adbId`. Re-using the same `adbId` reuses the existing session.
- `MirroringSession.start()` walks: `idle → connecting → streaming` (or `→ error`). On stop or device disconnect, `→ disconnected`.
- `consumerTask` (the video stream consumer) and `batteryTask` are stored as `Task<Void, Never>?` and cancelled on stop. Never start them without storing the handle.
- `DependencyContainer.shutdown()` awaits `mirroringManager.stopAll()`. If you add a new manager-owned background task, register its teardown there.
- `MirroringSession.State.==` compares `error(_)` cases by `localizedDescription` — preserve that custom equality if you add new cases.

## Forbidden

- Inline scrcpy binary protocol parsing inside views/managers — use the `Protocol/` types.
- `DispatchQueue` for video / pointer events — see `rules/concurrency.md`.
- New singletons or globals — sessions live on `MirroringManager.sessions`.
- Modifying scrcpy-server's binary or licensing files outside an explicit version-bump commit.
- Hard-coding screen dimensions; the device sends them via `DeviceMeta`. Use `session.resolution`.
