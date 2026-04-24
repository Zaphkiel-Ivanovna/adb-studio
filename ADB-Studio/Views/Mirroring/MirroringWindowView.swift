import AppKit
import SwiftUI

struct MirroringWindowView: View {
    let deviceId: String

    @EnvironmentObject private var mirroringManager: MirroringManager
    @EnvironmentObject private var deviceManager: DeviceManager
    @EnvironmentObject private var container: DependencyContainer

    @AppStorage("mirrorWindowFrames") private var windowFramesData: Data = Data()
    @State private var isPinned: Bool = false
    @State private var showStatusBar: Bool = true
    @State private var showShortcutsHelp: Bool = false
    @State private var resolvedWindow: NSWindow?
    @StateObject private var framePersister = FramePersister()

    var body: some View {
        Group {
            if let session = mirroringManager.session(for: deviceId) {
                sessionView(session: session)
            } else {
                placeholderView
            }
        }
        .frame(minWidth: 360, minHeight: 640)
        .navigationTitle(resolvedTitle)
        .background(windowBridge)
        .onChange(of: isPinned) { _, newValue in
            resolvedWindow?.level = newValue ? .floating : .normal
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { note in
            handleWindowFrameChange(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMoveNotification)) { note in
            handleWindowFrameChange(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mirroringShowShortcutsHelp)) { note in
            guard note.object as? String == deviceId else { return }
            withAnimation { showShortcutsHelp = true }
        }
        .onDisappear {
            framePersister.cancel()
            Task { await mirroringManager.stopSession(adbId: deviceId) }
        }
    }

    private func sessionView(session: MirroringSession) -> some View {
        ZStack {
            VStack(spacing: 0) {
                MirroringToolbar(
                    session: session,
                    isPinned: $isPinned,
                    onToggleFullscreen: { resolvedWindow?.toggleFullScreen(nil) },
                    onToggleStatusBar: { withAnimation(.easeInOut(duration: 0.2)) { showStatusBar.toggle() } },
                    onShowShortcuts: { withAnimation { showShortcutsHelp = true } }
                )

                Divider()

                ZStack {
                    Color.black
                    MirroringRenderView(
                        session: session,
                        rightClickOpensMenu: container.settingsStore.settings.mirroringRightClickOpensMenu
                    )
                    if case .connecting = session.state {
                        ProgressView("Connecting…")
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showStatusBar {
                    Divider()
                    MirroringStatusBar(session: session)
                }
            }

            if showShortcutsHelp {
                MirroringShortcutsOverlay(onDismiss: {
                    withAnimation { showShortcutsHelp = false }
                })
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No active mirroring session")
                .font(.headline)
            Text("Open the Mirror tab for this device to start one.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var windowBridge: some View {
        WindowAccessor { window in
            guard resolvedWindow !== window else { return }
            resolvedWindow = window
            window.level = isPinned ? .floating : .normal
            applySavedFrame(to: window)
        }
    }

    private var resolvedTitle: String {
        let device = deviceManager.devices.first(where: { $0.allAdbIds.contains(deviceId) })
        let base: String
        if let session = mirroringManager.session(for: deviceId) {
            base = session.deviceName
        } else if let device {
            base = device.displayName
        } else {
            base = deviceId
        }
        if let androidVersion = device?.androidVersion {
            return "Mirror — \(base) (Android \(androidVersion))"
        }
        return "Mirror — \(base)"
    }

    private var frameStorageKey: String {
        if let device = deviceManager.devices.first(where: { $0.allAdbIds.contains(deviceId) }) {
            return device.persistentSerial ?? device.adbId
        }
        return deviceId
    }

    private func handleWindowFrameChange(_ note: Notification) {
        guard let window = note.object as? NSWindow, window === resolvedWindow else { return }
        framePersister.schedule(frame: window.frame, key: frameStorageKey) { key, frame in
            persistFrame(frame, for: key)
        }
    }

    private func applySavedFrame(to window: NSWindow) {
        guard let map = decodeFrames(), let rect = map[frameStorageKey] else { return }
        window.setFrame(rect, display: true)
    }

    private func persistFrame(_ frame: CGRect, for key: String) {
        var map = decodeFrames() ?? [:]
        map[key] = frame
        if let encoded = try? JSONEncoder().encode(map) {
            windowFramesData = encoded
        }
    }

    private func decodeFrames() -> [String: CGRect]? {
        guard !windowFramesData.isEmpty else { return nil }
        return try? JSONDecoder().decode([String: CGRect].self, from: windowFramesData)
    }
}

@MainActor
final class FramePersister: ObservableObject {
    private var debounce: Task<Void, Never>?

    func schedule(frame: CGRect, key: String, save: @escaping (String, CGRect) -> Void) {
        debounce?.cancel()
        debounce = Task { [frame, key] in
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled { return }
            save(key, frame)
        }
    }

    func cancel() {
        debounce?.cancel()
        debounce = nil
    }
}
