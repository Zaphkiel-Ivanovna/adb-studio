import Foundation

@MainActor
final class PortForwardSettingsViewModel: ObservableObject {
    @Published private(set) var devices: [DeviceHistory] = []

    private let historyStore: DeviceHistoryStore

    init(historyStore: DeviceHistoryStore) {
        self.historyStore = historyStore
        reload()
    }

    func reload() {
        devices = historyStore.devicesWithPresets()
            .sorted { $0.displayLabel.localizedCaseInsensitiveCompare($1.displayLabel) == .orderedAscending }
    }

    func toggleAutoApply(_ preset: PortForwardPreset, for serial: String) {
        var updated = preset
        updated.autoApply.toggle()
        historyStore.updatePreset(updated, for: serial)
        reload()
    }

    func rename(_ preset: PortForwardPreset, to name: String, for serial: String) {
        var updated = preset
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        updated.name = trimmed.isEmpty ? nil : trimmed
        historyStore.updatePreset(updated, for: serial)
        reload()
    }

    func removePreset(_ preset: PortForwardPreset, for serial: String) {
        historyStore.removePreset(id: preset.id, for: serial)
        reload()
    }

    func clearPresets(for serial: String) {
        historyStore.setPresets([], for: serial)
        reload()
    }
}
