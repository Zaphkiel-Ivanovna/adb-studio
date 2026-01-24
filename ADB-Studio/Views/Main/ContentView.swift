import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var deviceManager: DeviceManager
    @State private var selectedDeviceId: String?
    @State private var showWiFiConnectionSheet = false
    @State private var showUpdateAlert = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedDeviceId: $selectedDeviceId,
                showWiFiConnectionSheet: $showWiFiConnectionSheet
            )
            .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            if let deviceId = selectedDeviceId,
               let device = deviceManager.device(withId: deviceId) {
                DeviceDetailView(
                    device: device,
                    adbService: container.adbService,
                    screenshotService: container.screenshotService,
                    deviceManager: deviceManager
                )
            } else {
                EmptyDetailView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            if container.updateService.updateAvailable {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showUpdateAlert = true
                    }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.white, .blue)
                    }
                    .help("Update available: v\(container.updateService.latestRelease?.version ?? "")")
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Settings")

                Button(action: {
                    showWiFiConnectionSheet = true
                }) {
                    Image(systemName: "wifi")
                }
                .help("Connect via WiFi")

                Button(action: {
                    Task {
                        await deviceManager.refresh()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .opacity(deviceManager.isRefreshing ? 0 : 1)
                        .overlay {
                            if deviceManager.isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                }
                .help("Refresh device list")
                .disabled(deviceManager.isRefreshing)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showWiFiConnectionSheet)) { _ in
            showWiFiConnectionSheet = true
        }
        .sheet(isPresented: $showWiFiConnectionSheet) {
            WiFiConnectionSheet(
                settingsStore: container.settingsStore,
                discoveryService: container.discoveryService,
                adbService: container.adbService
            )
        }
        .alert("ADB Not Found", isPresented: .constant(deviceManager.hasCheckedADB && !deviceManager.isADBAvailable)) {
            Button("OK") { }
        } message: {
            Text("Please install Android SDK platform-tools and ensure 'adb' is in your PATH.")
        }
        .onChange(of: container.updateService.updateAvailable) { _, available in
            if available { showUpdateAlert = true }
        }
        .alert("Update Available", isPresented: $showUpdateAlert) {
            if let dmgUrl = container.updateService.latestRelease?.dmgDownloadUrl,
               let url = URL(string: dmgUrl) {
                Button("Download Update") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("View on GitHub") {
                if let htmlUrl = container.updateService.latestRelease?.htmlUrl,
                   let url = URL(string: htmlUrl) {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text("Version \(container.updateService.latestRelease?.version ?? "") is available.")
        }
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Select a Device")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Choose a device from the list to view details and actions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(DependencyContainer())
}
