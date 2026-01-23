import SwiftUI

struct DeviceRowView: View {
    let device: Device
    @Environment(\.isEnabled) private var isEnabled

    private var connectionIcon: String {
        if device.connection.type == .usb {
            return device.hasMultipleConnections ? "cable.connector.horizontal" : "cable.connector"
        }
        return "wifi"
    }

    private var connectionDisplayString: String {
        if device.hasMultipleConnections {
            let types = device.allConnections.map { $0.type.displayName }
            let uniqueTypes = Array(Set(types)).sorted()
            return uniqueTypes.joined(separator: " + ")
        }
        return device.connection.displayString
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(device.state == .device ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "apps.iphone")
                    .font(.system(size: 18))
                    .foregroundColor(device.state == .device ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(device.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    DeviceStatusBadge(state: device.state)
                }

                if let brand = device.brand, let version = device.androidVersion {
                    Text("\(brand) • Android \(version)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let brand = device.brand {
                    Text(brand)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else if let version = device.androidVersion {
                    Text("Android \(version)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 3) {
                    Image(systemName: connectionIcon)
                        .font(.system(size: 9))

                    Text(connectionDisplayString)
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .frame(minHeight: 60)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.01))
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 0) {
        DeviceRowView(device: Device(
            adbId: "192.168.1.100:5555",
            persistentSerial: "ABC123",
            connection: .wifi(ipAddress: "192.168.1.100", port: 5555),
            state: .device,
            model: "Pixel 6",
            brand: "Google",
            androidVersion: "14"
        ))
        .padding()

        Divider()

        DeviceRowView(device: Device(
            adbId: "ABC123456",
            connection: .usb(),
            state: .unauthorized,
            model: "Galaxy S21",
            brand: "Samsung"
        ))
        .padding()
    }
    .frame(width: 300)
}
