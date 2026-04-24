import Foundation

enum MirroringError: LocalizedError {
    case adbUnavailable
    case serverBundleMissing
    case serverPushFailed(String)
    case serverLaunchFailed(String)
    case versionMismatch(expected: String, got: String)
    case handshakeTimeout
    case videoSocketClosed
    case controlSocketClosed
    case decoderFailed(OSStatus)
    case deviceDisconnected(String)
    case invalidDeviceMeta(String)

    var errorDescription: String? {
        switch self {
        case .adbUnavailable:
            return "ADB is not available. Please check your installation."
        case .serverBundleMissing:
            return "scrcpy-server resource is missing from the application bundle."
        case .serverPushFailed(let message):
            return "Failed to push scrcpy-server to device: \(message)"
        case .serverLaunchFailed(let message):
            return "Failed to launch scrcpy-server on device: \(message)"
        case .versionMismatch(let expected, let got):
            return "scrcpy-server version mismatch. Expected \(expected), got \(got)."
        case .handshakeTimeout:
            return "Timed out waiting for scrcpy-server to open video/control sockets."
        case .videoSocketClosed:
            return "Video socket closed unexpectedly."
        case .controlSocketClosed:
            return "Control socket closed unexpectedly."
        case .decoderFailed(let status):
            return "Video decoder failed with status \(status)."
        case .deviceDisconnected(let id):
            return "Device \(id) disconnected."
        case .invalidDeviceMeta(let detail):
            return "Invalid device metadata: \(detail)"
        }
    }
}
