import SwiftUI

enum DeviceDetailTab: String, CaseIterable, Identifiable {
    case info = "Info"
    case tools = "Tools"
    case apps = "Apps"
    case network = "Network"
    case power = "Power"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .info: return "info.circle"
        case .tools: return "wrench.and.screwdriver"
        case .apps: return "square.grid.2x2"
        case .network: return "network"
        case .power: return "power"
        }
    }
}

struct DeviceDetailView: View {
    let device: Device
    let adbService: ADBService
    let screenshotService: ScreenshotService
    let deviceManager: DeviceManager

    @StateObject private var viewModel: DeviceDetailViewModel
    @State private var selectedTab: DeviceDetailTab = .info

    init(device: Device, adbService: ADBService, screenshotService: ScreenshotService, deviceManager: DeviceManager) {
        self.device = device
        self.adbService = adbService
        self.screenshotService = screenshotService
        self.deviceManager = deviceManager
        _viewModel = StateObject(wrappedValue: DeviceDetailViewModel(
            device: device,
            adbService: adbService,
            screenshotService: screenshotService,
            deviceManager: deviceManager
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            DeviceHeaderView(viewModel: viewModel)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            if device.state == .device {
                Picker("", selection: $selectedTab) {
                    ForEach(DeviceDetailTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                Divider()

                tabContent
            } else {
                DeviceStateMessageView(state: device.state)
                    .padding(24)
                Spacer()
            }
        }
        .navigationTitle(device.displayName)
        .id(device.id)
        .onChange(of: device) { _, newDevice in
            viewModel.updateDevice(newDevice)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $viewModel.showAddPortSheet) {
            AddPortSheet(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .info:
            ScrollView {
                DeviceInfoSection(device: viewModel.device)
                    .padding(24)
            }
        case .tools:
            ScrollView {
                ToolsView(viewModel: viewModel)
                    .padding(24)
            }
        case .apps:
            ScrollView {
                VStack(spacing: 24) {
                    APKInstallerView(viewModel: viewModel)
                    InstalledAppsView(deviceId: device.bestAdbId, adbService: adbService)
                }
                .padding(24)
            }
        case .network:
            ScrollView {
                PortForwardView(viewModel: viewModel)
                    .padding(24)
            }
            .task { await viewModel.loadPortForwards() }
        case .power:
            ScrollView {
                PowerView(viewModel: viewModel)
                    .padding(24)
            }
        }
    }
}

struct DeviceHeaderView: View {
    @ObservedObject var viewModel: DeviceDetailViewModel

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 72, height: 72)

                Image(systemName: "apps.iphone")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                if viewModel.isEditingName {
                    HStack {
                        TextField("Device name", text: $viewModel.editedName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)

                        Button(action: viewModel.saveName) {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: viewModel.cancelEditingName) {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    HStack {
                        Text(viewModel.device.displayName)
                            .font(.title)
                            .fontWeight(.bold)

                        Button(action: viewModel.startEditingName) {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }

                Text(viewModel.device.fullDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    DeviceStatusBadge(state: viewModel.device.state)

                    Label(viewModel.device.connection.displayString, systemImage: viewModel.device.connection.type == .wifi ? "wifi" : "cable.connector")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let message = viewModel.successMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct DeviceStateMessageView: View {
    let state: DeviceState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: state == .unauthorized ? "lock.shield" : "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(state == .unauthorized ? "Device Unauthorized" : "Device Offline")
                .font(.title2)
                .fontWeight(.semibold)

            Text(state == .unauthorized
                 ? "Please accept the debugging authorization prompt on your device."
                 : "The device appears to be offline. Please check the connection.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    let settingsStore = SettingsStore()
    let adbService = ADBServiceImpl(settingsStore: settingsStore)
    return DeviceDetailView(
        device: Device(
            adbId: "192.168.1.100:5555",
            persistentSerial: "ABC123",
            connection: .wifi(ipAddress: "192.168.1.100", port: 5555),
            state: .device,
            model: "Pixel 6",
            brand: "Google",
            androidVersion: "14",
            sdkVersion: "34"
        ),
        adbService: adbService,
        screenshotService: ScreenshotService(adbService: adbService),
        deviceManager: DeviceManager(
            adbService: adbService,
            deviceIdentifier: DeviceIdentifier(adbService: adbService),
            historyStore: DeviceHistoryStore(),
            settingsStore: settingsStore
        )
    )
}
