import SwiftUI

struct WiFiConnectionSheet: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @Environment(\.dismiss) private var dismiss

    let settingsStore: SettingsStore
    @ObservedObject var discoveryService: DeviceDiscoveryService
    let adbService: ADBService

    @State private var selectedTab: ConnectionTab = .scan
    @State private var ipAddress = ""
    @State private var port = ""
    @State private var connectionError: String?
    @State private var isConnecting = false
    @State private var pairingDevice: DiscoveredDevice?

    @State private var pairIPAddress = ""
    @State private var pairPort = ""
    @State private var pairingCode = ""
    @State private var isPairing = false

    enum ConnectionTab {
        case scan
        case manual
        case pair
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("", selection: $selectedTab) {
                Text("Scan").tag(ConnectionTab.scan)
                Text("Manual").tag(ConnectionTab.manual)
                Text("Pair").tag(ConnectionTab.pair)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            switch selectedTab {
            case .scan:
                scanView
            case .manual:
                manualView
            case .pair:
                pairView
            }

            Spacer()
            bottomBar
        }
        .frame(width: 480, height: 500)
        .onAppear {
            port = String(settingsStore.settings.defaultTcpipPort)
            discoveryService.startScanning()
        }
        .onDisappear {
            discoveryService.stopScanning()
        }
        .sheet(item: $pairingDevice) { device in
            PairingSheet(
                device: device,
                adbService: adbService,
                discoveryService: discoveryService,
                deviceManager: deviceManager,
                onDismiss: { pairingDevice = nil }
            )
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "wifi")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("Connect via WiFi")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var scanView: some View {
        VStack(spacing: 0) {
            HStack {
                if discoveryService.isScanning {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning for devices...")
                        .foregroundColor(.secondary)
                } else {
                    Text("Found \(discoveryService.discoveredDevices.count) device(s)")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { discoveryService.startScanning() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(discoveryService.isScanning)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            if discoveryService.discoveredDevices.isEmpty {
                emptyDiscoveryView
            } else {
                deviceList
            }

            if let error = discoveryService.scanError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }

            if let error = connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
        }
    }

    private var emptyDiscoveryView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No devices found")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("To discover devices:")
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Enable Developer Options on your Android device")
                    Text("2. Enable Wireless Debugging")
                    Text("3. Ensure both devices are on the same network")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(discoveryService.discoveredDevices) { device in
                    DiscoveredDeviceRow(
                        device: device,
                        onConnect: { connectToDevice(device) },
                        onPair: { pairingDevice = device }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
    }

    private var manualView: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            .padding(.horizontal, 24)
            .padding(.top, 16)

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
            .padding(.horizontal, 24)

            if let error = connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }

            HStack {
                Spacer()
                Button("Connect") {
                    Task { await connectManually() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(ipAddress.isEmpty || port.isEmpty || isConnecting)
            }
            .padding(.horizontal, 24)
        }
    }

    private var pairView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("To pair a new device:")
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. On the phone: Developer options → Wireless debugging → Pair device with pairing code")
                    Text("2. Enter the IP, port and 6-digit code shown on the pairing screen")
                    Text("3. After pairing, switch to Manual to connect with the port shown on the main Wireless debugging screen")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IP Address")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("192.168.1.100", text: $pairIPAddress)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pair Port")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("41931", text: $pairPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Pairing Code")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("000000", text: $pairingCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .frame(width: 140)
                    .onChange(of: pairingCode) { _, newValue in
                        pairingCode = String(newValue.filter { $0.isNumber }.prefix(6))
                    }
            }
            .padding(.horizontal, 24)

            if let error = connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
            }

            if isPairing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Pairing…")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 24)
            }

            HStack {
                Spacer()
                Button("Pair") {
                    Task { await pairManually() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    pairIPAddress.isEmpty
                    || pairPort.isEmpty
                    || pairingCode.count != 6
                    || isPairing
                )
            }
            .padding(.horizontal, 24)
        }
    }

    private var bottomBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
        }
        .padding(24)
    }

    private func connectToDevice(_ device: DiscoveredDevice) {
        guard let address = device.connectAddress else {
            connectionError = "No connection address available"
            return
        }

        Task {
            discoveryService.markDeviceConnecting(device, true)
            connectionError = nil

            do {
                try await deviceManager.connect(to: address)
                dismiss()
            } catch let error as ADBError {
                connectionError = error.localizedDescription
            } catch {
                connectionError = error.localizedDescription
            }

            discoveryService.markDeviceConnecting(device, false)
        }
    }

    private func connectManually() async {
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
            try await deviceManager.connect(to: "\(trimmedIP):\(trimmedPort)")
            dismiss()
        } catch let error as ADBError {
            connectionError = error.localizedDescription
        } catch {
            connectionError = error.localizedDescription
        }

        isConnecting = false
    }

    private func pairManually() async {
        let trimmedIP = pairIPAddress.trimmingCharacters(in: .whitespaces)
        let trimmedPairPort = pairPort.trimmingCharacters(in: .whitespaces)
        let code = pairingCode.trimmingCharacters(in: .whitespaces)

        guard !trimmedIP.isEmpty else {
            connectionError = "Please enter an IP address"
            return
        }
        guard let pairPortNum = Int(trimmedPairPort), pairPortNum > 0, pairPortNum <= 65535 else {
            connectionError = "Please enter a valid pair port (1-65535)"
            return
        }
        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            connectionError = "Pairing code must be 6 digits"
            return
        }

        isPairing = true
        connectionError = nil

        do {
            try await adbService.pair(address: "\(trimmedIP):\(pairPortNum)", code: code)

            // Prefill Manual tab with the pair IP so the user only needs to enter the new connect port
            ipAddress = trimmedIP
            port = ""
            pairingCode = ""
            selectedTab = .manual
        } catch let error as ADBError {
            connectionError = error.localizedDescription
        } catch {
            connectionError = error.localizedDescription
        }

        isPairing = false
    }
}

// MARK: - DiscoveredDeviceRow

struct DiscoveredDeviceRow: View {
    let device: DiscoveredDevice
    let onConnect: () -> Void
    let onPair: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: deviceIcon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(device.host)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(device.serviceTypesDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if device.isConnecting {
                ProgressView()
                    .controlSize(.small)
            } else {
                HStack(spacing: 8) {
                    if device.canConnect && device.canPair {
                        Button("Connect") { onConnect() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }

                    if device.canPair {
                        Button("Pair") { onPair() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    } else if device.canConnect {
                        Button("Connect") { onConnect() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var deviceIcon: String {
        if device.canPair { return "lock.open.fill" }
        if device.canConnect { return "wifi" }
        return "antenna.radiowaves.left.and.right"
    }

    private var iconColor: Color {
        if device.canPair { return .orange }
        if device.canConnect { return .green }
        return .blue
    }
}

// MARK: - PairingSheet

struct PairingSheet: View {
    enum Phase: Equatable {
        case idle
        case pairing
        case waitingForConnectService
        case connecting
        case succeeded
    }

    let device: DiscoveredDevice
    let adbService: ADBService
    @ObservedObject var discoveryService: DeviceDiscoveryService
    let deviceManager: DeviceManager
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var pairingCode = ""
    @State private var phase: Phase = .idle
    @State private var error: String?
    @State private var pairingTask: Task<Void, Never>?

    private var pairingAddress: String {
        device.pairingAddress ?? device.displayAddress
    }

    private var isWorking: Bool {
        switch phase {
        case .pairing, .waitingForConnectService, .connecting: return true
        case .idle, .succeeded: return false
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            VStack(spacing: 2) {
                Text("Pair with \(device.name)")
                    .font(.headline)
                Text(pairingAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 4) {
                Text("Enter the 6-digit pairing code shown on your device")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Note: Pairing codes expire quickly. Enter the code promptly.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            TextField("000000", text: $pairingCode)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 150)
                .onChange(of: pairingCode) { _, newValue in
                    pairingCode = String(newValue.filter { $0.isNumber }.prefix(6))
                }

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            switch phase {
            case .waitingForConnectService:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Finalizing connection… accept Wireless Debugging if prompted.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            case .connecting:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting…")
                        .foregroundColor(.secondary)
                }
            case .succeeded:
                Label("Paired successfully!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .idle, .pairing:
                EmptyView()
            }

            HStack(spacing: 16) {
                Button("Cancel") {
                    pairingTask?.cancel()
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(phase == .succeeded)

                if phase != .succeeded {
                    Button(phase == .pairing ? "Pairing…" : "Pair") {
                        Task { await pairAndConnect() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pairingCode.count != 6 || phase != .idle)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(32)
        .frame(width: 340)
        .onDisappear { pairingTask?.cancel() }
    }

    private func pairAndConnect() async {
        phase = .pairing
        error = nil

        let task = Task {
            do {
                try await adbService.pair(address: pairingAddress, code: pairingCode)
                discoveryService.markDevicePaired(device)

                phase = .waitingForConnectService
                let connectAddress = try await waitForConnectAddress(deviceID: device.id, timeout: 30)

                phase = .connecting
                await deviceManager.refresh()
                try await deviceManager.connect(to: connectAddress)

                phase = .succeeded
                try? await Task.sleep(nanoseconds: 500_000_000)
                onDismiss()
                dismiss()

            } catch is CancellationError {
                phase = .idle
            } catch let err as ADBError {
                error = err.localizedDescription
                phase = .idle
            } catch {
                self.error = error.localizedDescription
                phase = .idle
            }
        }
        pairingTask = task
        await task.value
    }

    /// Polls `discoveryService.discoveredDevices` until the device with `deviceID`
    /// advertises `_adb-tls-connect._tcp`. `discoveredDevices` is updated
    /// reactively by mDNS delegate callbacks.
    private func waitForConnectAddress(deviceID: String, timeout: TimeInterval) async throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if let fresh = discoveryService.discoveredDevices.first(where: { $0.id == deviceID }),
               let address = fresh.connectAddress {
                return address
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw ADBError.connectServiceNotAdvertised(device.host)
    }
}

// MARK: - Preview

#Preview {
    let settingsStore = SettingsStore()
    let historyStore = DeviceHistoryStore()
    let adbService = ADBServiceImpl(settingsStore: settingsStore)
    return WiFiConnectionSheet(
        settingsStore: settingsStore,
        discoveryService: DeviceDiscoveryService(historyStore: historyStore),
        adbService: adbService
    )
    .environmentObject(DeviceManager(
        adbService: adbService,
        deviceIdentifier: DeviceIdentifier(adbService: adbService),
        historyStore: historyStore,
        settingsStore: settingsStore
    ))
}
