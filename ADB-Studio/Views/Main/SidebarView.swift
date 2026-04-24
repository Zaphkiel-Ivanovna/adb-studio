import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @Binding var selectedDeviceId: String?
    @Binding var showWiFiConnectionSheet: Bool

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if deviceManager.devices.isEmpty {
                    emptyStateView
                } else {
                    deviceListView
                }
            }
            .frame(maxHeight: .infinity)

            Divider()
            serverStatusBar
        }
        .navigationTitle("ADB Studio")
    }

    private var serverStatusBar: some View {
        HStack(spacing: 6) {
            if deviceManager.isStartingServer {
                ProgressView()
                    .controlSize(.small)
                Text("Starting ADB Server...")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if deviceManager.isServerRunning {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("ADB Server Running")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("ADB Server Stopped")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Start") {
                    Task { await deviceManager.ensureServerRunning() }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var deviceListView: some View {
        List(selection: $selectedDeviceId) {
            Section {
                ForEach(deviceManager.devices) { device in
                    DeviceRowView(device: device)
                        .tag(device.id)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .contextMenu {
                            if device.connection.isWiFiBased {
                                Button("Disconnect") {
                                    Task {
                                        try? await deviceManager.disconnect(from: device)
                                        if selectedDeviceId == device.id {
                                            selectedDeviceId = nil
                                        }
                                    }
                                }
                            }
                        }
                }
            } header: {
                Text("Devices")
                    .padding(.bottom, 4)
            }
        }
        .listStyle(.sidebar)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            if deviceManager.isRefreshing {
                ProgressView()
                    .controlSize(.large)
                Text("Scanning for devices...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("No Devices Found")
                    .font(.title3)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 8) {
                    Text("To connect a device:")
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Enable USB debugging on your device", systemImage: "1.circle")
                        Label("Connect via USB cable", systemImage: "2.circle")
                        Label("Or connect via WiFi", systemImage: "3.circle")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                Button(action: { showWiFiConnectionSheet = true }) {
                    Label("Connect via WiFi", systemImage: "wifi")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

#Preview {
    let settingsStore = SettingsStore()
    let adbService = ADBServiceImpl(settingsStore: settingsStore)
    return SidebarView(
        selectedDeviceId: .constant(nil),
        showWiFiConnectionSheet: .constant(false)
    )
    .environmentObject(DeviceManager(
        adbService: adbService,
        deviceIdentifier: DeviceIdentifier(adbService: adbService),
        historyStore: DeviceHistoryStore(),
        settingsStore: settingsStore
    ))
}
