import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var deviceManager: DeviceManager
    @State private var selectedDeviceId: String?
    @State private var showWiFiConnectionSheet = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selectedDeviceId: $selectedDeviceId,
                showWiFiConnectionSheet: $showWiFiConnectionSheet
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } content: {
            DeviceListView(selectedDeviceId: $selectedDeviceId)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
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
            ToolbarItemGroup(placement: .primaryAction) {
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
            WiFiConnectionSheet(settingsStore: container.settingsStore)
        }
        .alert("ADB Not Found", isPresented: .constant(deviceManager.hasCheckedADB && !deviceManager.isADBAvailable)) {
            Button("OK") { }
        } message: {
            Text("Please install Android SDK platform-tools and ensure 'adb' is in your PATH.")
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
