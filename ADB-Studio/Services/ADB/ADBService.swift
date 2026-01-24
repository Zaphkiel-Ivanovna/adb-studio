import Foundation

protocol ADBService {
    func isADBAvailable() async -> Bool
    func listDevices() async throws -> [Device]
    func connect(to address: String) async throws
    func disconnect(from address: String) async throws
    func pair(address: String, code: String) async throws
    func getProperty(_ property: String, deviceId: String) async throws -> String
    func getProperties(_ properties: [String], deviceId: String) async throws -> [String: String]
    func shell(_ command: String, deviceId: String) async throws -> String
    func takeScreenshot(deviceId: String) async throws -> Data
    func inputText(_ text: String, deviceId: String) async throws
    func inputKeyEvent(_ keyCode: Int, deviceId: String) async throws
    func listReverseForwards(deviceId: String) async throws -> [PortForward]
    func createReverseForward(localPort: Int, remotePort: Int, deviceId: String) async throws
    func removeReverseForward(localPort: Int, deviceId: String) async throws
    func removeAllReverseForwards(deviceId: String) async throws
    func enableTcpip(port: Int, deviceId: String) async throws
    func installAPK(path: URL, deviceId: String, onStart: @escaping (APKInstallHandle) -> Void, onProgress: @escaping (String) -> Void) async throws

    // App Management
    func listPackages(deviceId: String, filter: AppListFilter) async throws -> [String]
    func getPackageInfo(packageName: String, deviceId: String) async throws -> InstalledApp
    func launchApp(packageName: String, deviceId: String) async throws
    func forceStopApp(packageName: String, deviceId: String) async throws
    func uninstallApp(packageName: String, keepData: Bool, deviceId: String) async throws
    func disableApp(packageName: String, deviceId: String) async throws
    func enableApp(packageName: String, deviceId: String) async throws
    func openAppSettings(packageName: String, deviceId: String) async throws

    // Power Actions
    func reboot(deviceId: String, mode: RebootMode) async throws
}

enum AppListFilter {
    case all
    case thirdParty
    case system
    case disabled
}

final class APKInstallHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var _process: Process?

    func setProcess(_ process: Process) {
        lock.lock()
        defer { lock.unlock() }
        _process = process
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        guard let process = _process, process.isRunning else { return }
        process.terminate()
    }
}

enum AndroidKeyCode: Int {
    case back = 4
    case home = 3
    case menu = 82
    case volumeUp = 24
    case volumeDown = 25
    case power = 26
    case enter = 66
    case delete = 67
    case tab = 61
}

enum RebootMode: String, CaseIterable {
    case normal = ""
    case recovery = "recovery"
    case bootloader = "bootloader"
    case sideload = "sideload"
    case sideloadAutoReboot = "sideload-auto-reboot"

    var displayName: String {
        switch self {
        case .normal: return "Reboot"
        case .recovery: return "Recovery Mode"
        case .bootloader: return "Bootloader/Fastboot"
        case .sideload: return "Sideload Mode"
        case .sideloadAutoReboot: return "Sideload (Auto-Reboot)"
        }
    }

    var systemImage: String {
        switch self {
        case .normal: return "arrow.clockwise"
        case .recovery: return "wrench.and.screwdriver"
        case .bootloader: return "cpu"
        case .sideload: return "arrow.down.circle"
        case .sideloadAutoReboot: return "arrow.down.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .normal: return "Restart the device normally"
        case .recovery: return "Boot into recovery mode for system maintenance"
        case .bootloader: return "Boot into bootloader/fastboot mode"
        case .sideload: return "Boot into sideload mode for manual updates"
        case .sideloadAutoReboot: return "Sideload mode with automatic reboot after"
        }
    }
}
