import Foundation

enum ADBError: LocalizedError {
    case adbNotFound
    case deviceNotFound(String)
    case connectionFailed(String)
    case pairingFailed(String)
    case commandFailed(String, Int32)
    case parseError(String)
    case timeout
    case unauthorized(String)
    case offline(String)
    case installFailed(String)
    case appNotFound(String)
    case uninstallFailed(String)
    case appActionFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return "ADB executable not found. Please ensure Android SDK platform-tools is installed and in PATH."
        case .deviceNotFound(let deviceId):
            return "Device '\(deviceId)' not found. Please check the connection."
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .pairingFailed(let message):
            return "Pairing failed: \(message)"
        case .commandFailed(let command, let exitCode):
            return "Command '\(command)' failed with exit code \(exitCode)"
        case .parseError(let message):
            return "Failed to parse ADB output: \(message)"
        case .timeout:
            return "Operation timed out"
        case .unauthorized(let deviceId):
            return "Device '\(deviceId)' is unauthorized. Please accept the debugging prompt on the device."
        case .offline(let deviceId):
            return "Device '\(deviceId)' is offline. Please reconnect the device."
        case .installFailed(let message):
            return "Installation failed: \(message)"
        case .appNotFound(let packageName):
            return "App '\(packageName)' not found"
        case .uninstallFailed(let message):
            return "Uninstall failed: \(message)"
        case .appActionFailed(let action, let message):
            return "\(action) failed: \(message)"
        }
    }
}
