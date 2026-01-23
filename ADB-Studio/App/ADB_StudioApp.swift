import SwiftUI

@main
struct ADB_StudioApp: App {
    @StateObject private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(container.deviceManager)
                .onAppear {
                    container.start()
                }
                .onDisappear {
                    container.stop()
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
            SettingsView(settingsStore: container.settingsStore)
        }
    }
}

extension Notification.Name {
    static let showWiFiConnectionSheet = Notification.Name("showWiFiConnectionSheet")
}
