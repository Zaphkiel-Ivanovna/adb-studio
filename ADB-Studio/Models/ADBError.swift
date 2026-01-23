import Foundation

enum ADBError: LocalizedError {
    case adbNotFound
    case deviceNotFound(String)
    case connectionFailed(String)
    case commandFailed(String, Int32)
    case parseError(String)
    case timeout
    case unauthorized(String)
    case offline(String)

    var errorDescription: String? {
        switch self {
        case .adbNotFound:
            return "ADB executable not found. Please ensure Android SDK platform-tools is installed and in PATH."
        case .deviceNotFound(let deviceId):
            return "Device '\(deviceId)' not found. Please check the connection."
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
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
        }
    }
}
