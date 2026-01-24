import Foundation
import AppKit

@MainActor
final class DeviceDetailViewModel: ObservableObject {
    @Published var device: Device
    @Published var portForwards: [PortForward] = []
    @Published var isLoadingPorts = false
    @Published var textToSend = ""
    @Published var isSendingText = false
    @Published var isTakingScreenshot = false
    @Published var showAddPortSheet = false
    @Published var newPortLocal = ""
    @Published var newPortRemote = ""
    @Published var isAddingPort = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isEditingName = false
    @Published var editedName = ""
    @Published var tcpipPort = "5555"
    @Published var isEnablingTcpip = false
    @Published var isInstallingAPK = false
    @Published var apkInstallProgress: String = ""
    @Published var apkInstallResult: APKInstallResult?
    @Published var isRebooting = false
    @Published var showRebootConfirmation = false
    @Published var pendingRebootMode: RebootMode?
    private var apkInstallTask: Task<Void, Never>?
    private var apkInstallHandle: APKInstallHandle?

    enum APKInstallResult: Equatable {
        case success
        case failure(String)
    }

    private let adbService: ADBService
    private let screenshotService: ScreenshotService
    private let deviceManager: DeviceManager

    init(device: Device, adbService: ADBService, screenshotService: ScreenshotService, deviceManager: DeviceManager) {
        self.device = device
        self.adbService = adbService
        self.screenshotService = screenshotService
        self.deviceManager = deviceManager
        self.editedName = device.customName ?? ""
    }

    func updateDevice(_ device: Device) {
        self.device = device
        self.editedName = device.customName ?? ""
    }

    func sendText() async {
        guard !textToSend.isEmpty else { return }

        isSendingText = true
        errorMessage = nil

        do {
            try await adbService.inputText(textToSend, deviceId: device.bestAdbId)
            textToSend = ""
            showSuccess("Text sent")
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isSendingText = false
    }

    func sendKeyEvent(_ keyCode: AndroidKeyCode) async {
        errorMessage = nil

        do {
            try await adbService.inputKeyEvent(keyCode.rawValue, deviceId: device.bestAdbId)
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func takeScreenshotToClipboard() async {
        isTakingScreenshot = true
        errorMessage = nil

        do {
            try await screenshotService.takeScreenshotToClipboard(deviceId: device.bestAdbId)
            showSuccess("Screenshot copied to clipboard")
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isTakingScreenshot = false
    }

    func saveScreenshot() async {
        isTakingScreenshot = true
        errorMessage = nil

        do {
            let url = try await screenshotService.saveScreenshotToDownloads(
                deviceId: device.bestAdbId,
                deviceName: device.displayName
            )
            showSuccess("Screenshot saved to \(url.lastPathComponent)")
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isTakingScreenshot = false
    }

    func loadPortForwards() async {
        isLoadingPorts = true

        do {
            portForwards = try await adbService.listReverseForwards(deviceId: device.bestAdbId)
        } catch {
            print("Failed to load port forwards: \(error)")
            portForwards = []
        }

        isLoadingPorts = false
    }

    func addPortForward() async {
        guard let local = Int(newPortLocal), let remote = Int(newPortRemote) else {
            errorMessage = "Please enter valid port numbers"
            return
        }

        guard local > 0, local <= 65535, remote > 0, remote <= 65535 else {
            errorMessage = "Port must be between 1 and 65535"
            return
        }

        isAddingPort = true
        errorMessage = nil

        do {
            try await adbService.createReverseForward(localPort: local, remotePort: remote, deviceId: device.bestAdbId)
            showAddPortSheet = false
            newPortLocal = ""
            newPortRemote = ""
            await loadPortForwards()
            showSuccess("Port forward created")
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isAddingPort = false
    }

    func removePortForward(_ forward: PortForward) async {
        errorMessage = nil

        do {
            try await adbService.removeReverseForward(localPort: forward.localPort, deviceId: device.bestAdbId)
            await loadPortForwards()
            showSuccess("Port forward removed")
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeAllPortForwards() async {
        errorMessage = nil

        do {
            try await adbService.removeAllReverseForwards(deviceId: device.bestAdbId)
            await loadPortForwards()
            showSuccess("All port forwards removed")
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func enableTcpip() async {
        guard let portNum = Int(tcpipPort), portNum > 0, portNum <= 65535 else {
            errorMessage = "Invalid port (1-65535)"
            return
        }

        isEnablingTcpip = true
        errorMessage = nil

        let ipAddress = device.allConnections
            .first { $0.isWiFiBased && $0.ipAddress != nil }?
            .ipAddress

        do {
            try await adbService.enableTcpip(port: portNum, deviceId: device.bestAdbId)

            if device.connection.type == .usb && !device.hasMultipleConnections {
                showSuccess("TCP/IP enabled on port \(portNum). You can now disconnect USB.")
            } else if let ip = ipAddress {
                try await deviceManager.disconnect(from: device)
                try? await Task.sleep(for: .milliseconds(500))
                try await deviceManager.connect(to: "\(ip):\(portNum)")
                showSuccess("Reconnected on port \(portNum)")
            } else {
                showSuccess("Port changed to \(portNum)")
            }
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isEnablingTcpip = false
    }

    func disconnectDevice() async {
        guard device.connection.isWiFiBased || device.hasMultipleConnections else { return }

        do {
            try await deviceManager.disconnect(from: device)
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startEditingName() {
        editedName = device.customName ?? ""
        isEditingName = true
    }

    func saveName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespaces)
        deviceManager.setCustomName(trimmed.isEmpty ? nil : trimmed, for: device)
        isEditingName = false

        device.customName = trimmed.isEmpty ? nil : trimmed
    }

    func cancelEditingName() {
        editedName = device.customName ?? ""
        isEditingName = false
    }

    func installAPK(url: URL) {
        guard url.pathExtension.lowercased() == "apk" else {
            errorMessage = "Please select a valid APK file"
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "File not found"
            return
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            errorMessage = "Cannot read file"
            return
        }

        isInstallingAPK = true
        apkInstallProgress = "Preparing installation..."
        apkInstallResult = nil
        errorMessage = nil

        apkInstallTask = Task {
            do {
                try await adbService.installAPK(
                    path: url,
                    deviceId: device.bestAdbId,
                    onStart: { [weak self] handle in
                        self?.apkInstallHandle = handle
                    },
                    onProgress: { [weak self] progress in
                        self?.apkInstallProgress = progress
                    }
                )
                apkInstallTask = nil
                apkInstallResult = .success
            } catch is CancellationError {
                apkInstallTask = nil
                apkInstallHandle = nil
                isInstallingAPK = false
                apkInstallResult = nil
            } catch let error as ADBError {
                apkInstallTask = nil
                apkInstallResult = .failure(error.localizedDescription)
            } catch {
                apkInstallTask = nil
                apkInstallResult = .failure(error.localizedDescription)
            }
        }
    }

    func cancelAPKInstall() {
        apkInstallHandle?.cancel()
        apkInstallTask?.cancel()
        apkInstallTask = nil
        apkInstallHandle = nil
        isInstallingAPK = false
        apkInstallProgress = ""
        apkInstallResult = nil
    }

    func dismissAPKInstall() {
        apkInstallHandle = nil
        isInstallingAPK = false
        apkInstallProgress = ""
        apkInstallResult = nil
    }

    private func showSuccess(_ message: String) {
        successMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if successMessage == message {
                successMessage = nil
            }
        }
    }

    // MARK: - Power Actions

    func requestReboot(mode: RebootMode) {
        pendingRebootMode = mode
        showRebootConfirmation = true
    }

    func confirmReboot() async {
        guard let mode = pendingRebootMode else { return }

        showRebootConfirmation = false
        isRebooting = true
        errorMessage = nil

        do {
            try await adbService.reboot(deviceId: device.bestAdbId, mode: mode)
            showSuccess("Device is rebooting...")
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isRebooting = false
        pendingRebootMode = nil
    }

    func cancelReboot() {
        showRebootConfirmation = false
        pendingRebootMode = nil
    }
}
