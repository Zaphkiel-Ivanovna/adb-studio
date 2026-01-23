import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @Binding var selectedDeviceId: String?

    var body: some View {
        List(selection: $selectedDeviceId) {
            ForEach(deviceManager.devices) { device in
                DeviceRowView(device: device)
                    .tag(device.id)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowSeparator(.visible)
                    .contextMenu {
                        if device.connection.type == .wifi {
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
        }
        .listStyle(.plain)
        .navigationTitle("Connected Devices")
        .overlay {
            if deviceManager.devices.isEmpty && !deviceManager.isRefreshing {
                EmptyDeviceListView()
            }
        }
    }
}

struct EmptyDeviceListView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Devices Found")
                .font(.title3)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 8) {
                Text("To connect a device:")
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Enable USB debugging on your device", systemImage: "1.circle")
                    Label("Connect via USB cable", systemImage: "2.circle")
                    Label("Or use WiFi connection", systemImage: "3.circle")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    DeviceListView(selectedDeviceId: .constant(nil))
        .environmentObject(DeviceManager(
            adbService: ADBServiceImpl(),
            deviceIdentifier: DeviceIdentifier(adbService: ADBServiceImpl()),
            historyStore: DeviceHistoryStore()
        ))
}
