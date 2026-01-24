import SwiftUI

struct ToolsView: View {
    @ObservedObject var viewModel: DeviceDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tools")
                .font(.headline)

            ScreenshotSection(viewModel: viewModel)
            TextInputSection(viewModel: viewModel)
            QuickActionsSection(viewModel: viewModel)
            TcpipSection(viewModel: viewModel)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ScreenshotSection: View {
    @ObservedObject var viewModel: DeviceDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Screenshot", systemImage: "camera")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        await viewModel.takeScreenshotToClipboard()
                    }
                }) {
                    Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                }
                .disabled(viewModel.isTakingScreenshot)

                Button(action: {
                    Task {
                        await viewModel.saveScreenshot()
                    }
                }) {
                    Label("Save to Downloads", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.isTakingScreenshot)

                if viewModel.isTakingScreenshot {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }
}

struct TextInputSection: View {
    @ObservedObject var viewModel: DeviceDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Send Text", systemImage: "keyboard")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                TextField("Type text to send...", text: $viewModel.textToSend)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await viewModel.sendText()
                        }
                    }

                Button(action: {
                    Task {
                        await viewModel.sendText()
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(viewModel.textToSend.isEmpty || viewModel.isSendingText)
            }
        }
    }
}

struct QuickActionsSection: View {
    @ObservedObject var viewModel: DeviceDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Quick Actions", systemImage: "bolt")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Back",
                    systemImage: "arrow.left",
                    action: {
                        Task {
                            await viewModel.sendKeyEvent(.back)
                        }
                    }
                )

                QuickActionButton(
                    title: "Home",
                    systemImage: "house",
                    action: {
                        Task {
                            await viewModel.sendKeyEvent(.home)
                        }
                    }
                )

                QuickActionButton(
                    title: "Menu",
                    systemImage: "line.3.horizontal",
                    action: {
                        Task {
                            await viewModel.sendKeyEvent(.menu)
                        }
                    }
                )

                QuickActionButton(
                    title: "Enter",
                    systemImage: "return",
                    action: {
                        Task {
                            await viewModel.sendKeyEvent(.enter)
                        }
                    }
                )
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)

                Text(title)
                    .font(.caption)
            }
            .frame(width: 60, height: 60)
        }
        .buttonStyle(.bordered)
    }
}

struct TcpipSection: View {
    @ObservedObject var viewModel: DeviceDetailViewModel

    private var isUSBOnly: Bool {
        viewModel.device.connection.type == .usb && !viewModel.device.hasMultipleConnections
    }

    private var hasWiFiConnection: Bool {
        viewModel.device.connection.isWiFiBased ||
        viewModel.device.additionalConnections.contains { $0.isWiFiBased }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("WiFi Mode (TCP/IP)", systemImage: "wifi")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 12) {
                Text(isUSBOnly ? "Enable wireless debugging on port:" : "Change port to:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("5555", text: $viewModel.tcpipPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)

                Button(action: {
                    Task { await viewModel.enableTcpip() }
                }) {
                    if viewModel.isEnablingTcpip {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(isUSBOnly ? "Enable" : "Apply")
                    }
                }
                .disabled(viewModel.isEnablingTcpip)

                if hasWiFiConnection {
                    Button("Disconnect WiFi") {
                        Task { await viewModel.disconnectDevice() }
                    }
                }
            }

            if isUSBOnly {
                Text("After enabling, disconnect USB and connect via WiFi using the device IP.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if hasWiFiConnection && viewModel.tcpipPort != "5555" {
                Text("After changing the port, disconnect and reconnect using the new port.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isUSBOnly || viewModel.tcpipPort != "5555" {
                Text("Note: The port resets to default (5555) when the Android device restarts.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

struct PowerView: View {
    @ObservedObject var viewModel: DeviceDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Power")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // Warning banner
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("These actions will interrupt device operation. The device will temporarily disconnect from ADB.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

                // Reboot options grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(RebootMode.allCases, id: \.self) { mode in
                        PowerActionButton(
                            mode: mode,
                            isRebooting: viewModel.isRebooting,
                            action: { viewModel.requestReboot(mode: mode) }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .confirmationDialog(
            "Confirm Reboot",
            isPresented: $viewModel.showRebootConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirm", role: .destructive) {
                Task { await viewModel.confirmReboot() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelReboot()
            }
        } message: {
            if let mode = viewModel.pendingRebootMode {
                Text("Are you sure you want to \(mode.displayName.lowercased())? The device will disconnect temporarily.")
            }
        }
    }
}

struct PowerActionsSection: View {
    @ObservedObject var viewModel: DeviceDetailViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack {
                    Label("Power Actions", systemImage: "power")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Warning banner
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)

                        Text("These actions will interrupt device operation. The device will temporarily disconnect from ADB.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)

                    // Reboot options grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        ForEach(RebootMode.allCases, id: \.self) { mode in
                            PowerActionButton(
                                mode: mode,
                                isRebooting: viewModel.isRebooting,
                                action: { viewModel.requestReboot(mode: mode) }
                            )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .confirmationDialog(
            "Confirm Reboot",
            isPresented: $viewModel.showRebootConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirm", role: .destructive) {
                Task { await viewModel.confirmReboot() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelReboot()
            }
        } message: {
            if let mode = viewModel.pendingRebootMode {
                Text("Are you sure you want to \(mode.displayName.lowercased())? The device will disconnect temporarily.")
            }
        }
    }
}

struct PowerActionButton: View {
    let mode: RebootMode
    let isRebooting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if isRebooting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(height: 20)
                } else {
                    Image(systemName: mode.systemImage)
                        .font(.title3)
                }

                Text(mode.displayName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .help(mode.description)
        }
        .buttonStyle(.bordered)
        .disabled(isRebooting)
    }
}

#Preview {
    let settingsStore = SettingsStore()
    let adbService = ADBServiceImpl(settingsStore: settingsStore)
    return ToolsView(viewModel: DeviceDetailViewModel(
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
