import Foundation
import Combine

final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private let settingsKey = "app_settings"

    @Published private(set) var settings: AppSettings {
        didSet {
            save()
            settingsChanged.send(settings)
        }
    }

    let settingsChanged = PassthroughSubject<AppSettings, Never>()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.load(from: defaults)
    }

    func update(_ transform: (inout AppSettings) -> Void) {
        var newSettings = settings
        transform(&newSettings)
        settings = newSettings
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: settingsKey)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }

    private static func load(from defaults: UserDefaults) -> AppSettings {
        guard let data = defaults.data(forKey: "app_settings") else {
            return AppSettings()
        }

        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
            return AppSettings()
        }
    }
}
