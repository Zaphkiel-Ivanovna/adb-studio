import SwiftUI

struct PortForwardView: View {
    @ObservedObject var viewModel: DeviceDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Port Forwarding")
                    .font(.headline)

                Spacer()

                if viewModel.isLoadingPorts {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(action: {
                    Task {
                        await viewModel.loadPortForwards()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoadingPorts)

                Button(action: {
                    viewModel.showAddPortSheet = true
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }

            if viewModel.portForwards.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Text("No port forwards")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("Add a reverse port forward for React Native, Flutter, etc.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.portForwards) { forward in
                        PortForwardRow(forward: forward) {
                            Task {
                                await viewModel.removePortForward(forward)
                            }
                        }
                    }
                }

                if viewModel.portForwards.count > 1 {
                    Button(action: {
                        Task {
                            await viewModel.removeAllPortForwards()
                        }
                    }) {
                        Label("Remove All", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct PortForwardRow: View {
    let forward: PortForward
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "arrow.left.arrow.right")
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(forward.displayString)
                    .font(.subheadline)

                Text("adb reverse \(forward.localSpec) \(forward.remoteSpec)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    let settingsStore = SettingsStore()
    let adbService = ADBServiceImpl(settingsStore: settingsStore)
    return PortForwardView(viewModel: DeviceDetailViewModel(
        device: Device(
            adbId: "test",
            connection: .usb(),
            state: .device
        ),
        adbService: adbService,
        screenshotService: ScreenshotService(adbService: adbService),
        deviceManager: DeviceManager(
            adbService: adbService,
            deviceIdentifier: DeviceIdentifier(adbService: adbService),
            historyStore: DeviceHistoryStore(),
            settingsStore: settingsStore
        )
    ))
    .padding()
}
