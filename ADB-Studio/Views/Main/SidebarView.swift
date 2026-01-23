import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @Binding var selectedDeviceId: String?
    @Binding var showWiFiConnectionSheet: Bool

    var body: some View {
        List(selection: $selectedDeviceId) {
            Section("Devices") {
                if deviceManager.devices.isEmpty {
                    if deviceManager.isRefreshing {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Scanning...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No devices connected")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else {
                    ForEach(deviceManager.devices) { device in
                        SidebarDeviceRow(device: device)
                            .tag(device.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ADB Studio")
    }
}

struct SidebarDeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.connection.type == .wifi ? "wifi" : "cable.connector")
                .font(.system(size: 12))
                .foregroundColor(device.state == .device ? .green : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(device.state.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(device.state == .device ? .secondary : .orange)
            }
        }
        .padding(.vertical, 3)
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
