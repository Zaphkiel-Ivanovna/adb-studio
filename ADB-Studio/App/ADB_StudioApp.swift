import SwiftUI
import AppKit

@main
struct ADB_StudioApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: ADBStudioAppDelegate
    @StateObject private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(container.deviceManager)
                .environmentObject(container.mirroringManager)
                .onAppear {
                    container.start()
                    appDelegate.container = container
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1000, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandMenu("Devices") {
                Button("Refresh") {
                    Task {
                        await container.deviceManager.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Connect via WiFi...") {
                    NotificationCenter.default.post(name: .showWiFiConnectionSheet, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        Settings {
            SettingsView(
                settingsStore: container.settingsStore,
                historyStore: container.historyStore
            )
        }

        WindowGroup(id: "mirror", for: String.self) { $deviceId in
            MirroringWindowView(deviceId: deviceId ?? "")
                .environmentObject(container)
                .environmentObject(container.mirroringManager)
                .environmentObject(container.deviceManager)
        }
        .defaultSize(width: 540, height: 960)
    }
}

extension Notification.Name {
    static let showWiFiConnectionSheet = Notification.Name("showWiFiConnectionSheet")
}

@MainActor
final class ADBStudioAppDelegate: NSObject, NSApplicationDelegate {
    weak var container: DependencyContainer?

    nonisolated func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task { @MainActor in
            if let container {
                await container.shutdown()
            }
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
