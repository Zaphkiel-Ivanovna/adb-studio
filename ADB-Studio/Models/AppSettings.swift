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
    var mirroringMaxSize: Int = 0
    var mirroringMaxFps: Int = 60
    var mirroringTurnOffDisplayOnStart: Bool = false
    var mirroringStayAwake: Bool = false
    var mirroringShowTouches: Bool = false
    var mirroringClipboardAutosync: Bool = false
    var mirroringRightClickOpensMenu: Bool = false

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

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        self.refreshInterval = try c.decodeIfPresent(Double.self, forKey: .refreshInterval) ?? defaults.refreshInterval
        self.customADBPath = try c.decodeIfPresent(String.self, forKey: .customADBPath)
        self.useCustomADBPath = try c.decodeIfPresent(Bool.self, forKey: .useCustomADBPath) ?? defaults.useCustomADBPath
        self.defaultTcpipPort = try c.decodeIfPresent(Int.self, forKey: .defaultTcpipPort) ?? defaults.defaultTcpipPort
        self.autoConnectLastDevices = try c.decodeIfPresent(Bool.self, forKey: .autoConnectLastDevices) ?? defaults.autoConnectLastDevices
        self.showConnectionNotifications = try c.decodeIfPresent(Bool.self, forKey: .showConnectionNotifications) ?? defaults.showConnectionNotifications
        self.screenshotSaveLocation = try c.decodeIfPresent(ScreenshotLocation.self, forKey: .screenshotSaveLocation) ?? defaults.screenshotSaveLocation
        self.checkForUpdatesOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .checkForUpdatesOnLaunch) ?? defaults.checkForUpdatesOnLaunch
        self.mirroringMaxSize = try c.decodeIfPresent(Int.self, forKey: .mirroringMaxSize) ?? defaults.mirroringMaxSize
        self.mirroringMaxFps = try c.decodeIfPresent(Int.self, forKey: .mirroringMaxFps) ?? defaults.mirroringMaxFps
        self.mirroringTurnOffDisplayOnStart = try c.decodeIfPresent(Bool.self, forKey: .mirroringTurnOffDisplayOnStart) ?? defaults.mirroringTurnOffDisplayOnStart
        self.mirroringStayAwake = try c.decodeIfPresent(Bool.self, forKey: .mirroringStayAwake) ?? defaults.mirroringStayAwake
        self.mirroringShowTouches = try c.decodeIfPresent(Bool.self, forKey: .mirroringShowTouches) ?? defaults.mirroringShowTouches
        self.mirroringClipboardAutosync = try c.decodeIfPresent(Bool.self, forKey: .mirroringClipboardAutosync) ?? defaults.mirroringClipboardAutosync
        self.mirroringRightClickOpensMenu = try c.decodeIfPresent(Bool.self, forKey: .mirroringRightClickOpensMenu) ?? defaults.mirroringRightClickOpensMenu
    }
}
