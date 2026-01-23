import SwiftUI

struct AddPortSheet: View {
    @ObservedObject var viewModel: DeviceDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                Text("Add Port Forward")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text("Create a reverse port forward to connect your development server to the device (e.g., React Native Metro bundler on port 8081).")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device Port")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("8081", text: $viewModel.newPortLocal)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }

                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local Port")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("8081", text: $viewModel.newPortRemote)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Presets")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        PresetButton(title: "React Native", port: "8081") {
                            viewModel.newPortLocal = "8081"
                            viewModel.newPortRemote = "8081"
                        }

                        PresetButton(title: "Flutter", port: "8080") {
                            viewModel.newPortLocal = "8080"
                            viewModel.newPortRemote = "8080"
                        }

                        PresetButton(title: "Expo", port: "19000") {
                            viewModel.newPortLocal = "19000"
                            viewModel.newPortRemote = "19000"
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    viewModel.newPortLocal = ""
                    viewModel.newPortRemote = ""
                    viewModel.errorMessage = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    Task {
                        await viewModel.addPortForward()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.newPortLocal.isEmpty || viewModel.newPortRemote.isEmpty || viewModel.isAddingPort)
            }
        }
        .padding(24)
        .frame(width: 360, height: 340)
    }
}

struct PresetButton: View {
    let title: String
    let port: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                Text(port)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    AddPortSheet(viewModel: DeviceDetailViewModel(
        device: Device(
            adbId: "test",
            connection: .usb(),
            state: .device
        ),
        adbService: ADBServiceImpl(),
        screenshotService: ScreenshotService(adbService: ADBServiceImpl()),
        deviceManager: DeviceManager(
            adbService: ADBServiceImpl(),
            deviceIdentifier: DeviceIdentifier(adbService: ADBServiceImpl()),
            historyStore: DeviceHistoryStore()
        )
    ))
}
