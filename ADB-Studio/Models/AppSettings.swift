import Foundation

struct AppSettings: Codable, Equatable {
    var refreshInterval: Double = 3.0
    var customADBPath: String? = nil
    var useCustomADBPath: Bool = false
    var defaultTcpipPort: Int = 5555
    var autoConnectLastDevices: Bool = false
    var showConnectionNotifications: Bool = true
    var screenshotSaveLocation: ScreenshotLocation = .downloads
    var checkForUpdatesOnLaunch: Bool = true

    enum ScreenshotLocation: String, Codable, CaseIterable {
        case downloads = "downloads"
        case desktop = "desktop"
        case custom = "custom"

        var displayName: String {
            switch self {
            case .downloads: return "Downloads"
            case .desktop: return "Desktop"
            case .custom: return "Custom..."
            }
        }
    }

    var effectiveADBPath: String? {
        if useCustomADBPath, let path = customADBPath, !path.isEmpty {
            return path
        }
        return nil
    }
}
