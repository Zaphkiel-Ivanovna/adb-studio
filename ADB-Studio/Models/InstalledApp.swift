import Foundation

struct InstalledApp: Identifiable, Equatable {
    let packageName: String
    var displayName: String?
    var versionName: String?
    var versionCode: Int?
    var installTime: Date?
    var updateTime: Date?
    var isSystemApp: Bool
    var isEnabled: Bool

    var id: String { packageName }

    var effectiveDisplayName: String {
        displayName ?? packageName.components(separatedBy: ".").last ?? packageName
    }
}

enum AppFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case user = "User Apps"
    case system = "System"
    case disabled = "Disabled"

    var id: String { rawValue }
}

enum AppSortOrder: String, CaseIterable, Identifiable {
    case name = "Name"
    case packageName = "Package"
    case updateTime = "Updated"
    case installTime = "Installed"

    var id: String { rawValue }
}

enum AppAction: Equatable {
    case launch
    case forceStop
    case uninstall
    case uninstallKeepData
    case disable
    case enable
    case openSettings

    var displayName: String {
        switch self {
        case .launch: return "Launch"
        case .forceStop: return "Force Stop"
        case .uninstall: return "Uninstall"
        case .uninstallKeepData: return "Uninstall (Keep Data)"
        case .disable: return "Disable"
        case .enable: return "Enable"
        case .openSettings: return "App Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .launch: return "play.fill"
        case .forceStop: return "stop.fill"
        case .uninstall: return "trash"
        case .uninstallKeepData: return "trash.slash"
        case .disable: return "nosign"
        case .enable: return "checkmark.circle"
        case .openSettings: return "gear"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .uninstall, .uninstallKeepData, .disable: return true
        default: return false
        }
    }
}
