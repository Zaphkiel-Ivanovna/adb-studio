import SwiftUI

struct DeviceInfoSection: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Information")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InfoRow(label: "Model", value: device.model ?? "Unknown")
                InfoRow(label: "Brand", value: device.brand ?? "Unknown")
                InfoRow(label: "Android Version", value: device.androidVersion ?? "Unknown")
                InfoRow(label: "SDK Level", value: device.sdkVersion ?? "Unknown")
                InfoRow(label: "Serial", value: device.persistentSerial ?? device.adbId)
                InfoRow(label: "Connection", value: device.connection.displayString)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    DeviceInfoSection(device: Device(
        adbId: "192.168.1.100:5555",
        persistentSerial: "ABC123DEF456",
        connection: .wifi(ipAddress: "192.168.1.100", port: 5555),
        state: .device,
        model: "Pixel 6",
        brand: "Google",
        androidVersion: "14",
        sdkVersion: "34"
    ))
    .padding()
}
