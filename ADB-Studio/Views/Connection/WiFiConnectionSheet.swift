import SwiftUI

struct WiFiConnectionSheet: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @Environment(\.dismiss) private var dismiss

    @State private var ipAddress = ""
    @State private var port = "5555"
    @State private var connectionError: String?
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "wifi")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Connect via WiFi")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("To connect wirelessly:")
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Enable Wireless Debugging or enable TCP/IP from a USB device")
                    Text("2. Get the IP from Settings > About phone > IP address")
                    Text("3. Enter the IP and port below")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IP Address")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("192.168.1.100", text: $ipAddress)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Port")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("5555", text: $port)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }

                if let error = connectionError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Connect") {
                    Task { await connect() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(ipAddress.isEmpty || port.isEmpty || isConnecting)
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
        .onSubmit {
            Task { await connect() }
        }
    }

    private var connectionAddress: String {
        let trimmedIP = ipAddress.trimmingCharacters(in: .whitespaces)
        let trimmedPort = port.trimmingCharacters(in: .whitespaces)
        return "\(trimmedIP):\(trimmedPort)"
    }

    private func connect() async {
        let trimmedIP = ipAddress.trimmingCharacters(in: .whitespaces)
        let trimmedPort = port.trimmingCharacters(in: .whitespaces)

        guard !trimmedIP.isEmpty else {
            connectionError = "Please enter an IP address"
            return
        }

        guard !trimmedPort.isEmpty, let portNum = Int(trimmedPort), portNum > 0, portNum <= 65535 else {
            connectionError = "Please enter a valid port (1-65535)"
            return
        }

        isConnecting = true
        connectionError = nil

        do {
            try await deviceManager.connect(to: connectionAddress)
            dismiss()
        } catch let error as ADBError {
            connectionError = error.localizedDescription
        } catch {
            connectionError = error.localizedDescription
        }

        isConnecting = false
    }
}

#Preview {
    let settingsStore = SettingsStore()
    let adbService = ADBServiceImpl(settingsStore: settingsStore)
    return WiFiConnectionSheet()
        .environmentObject(DeviceManager(
            adbService: adbService,
            deviceIdentifier: DeviceIdentifier(adbService: adbService),
            historyStore: DeviceHistoryStore(),
            settingsStore: settingsStore
        ))
}
