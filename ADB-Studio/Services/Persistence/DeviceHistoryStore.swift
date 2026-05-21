import Foundation

final class DeviceHistoryStore {
    private let defaults: UserDefaults
    private let historyKey = "device_history"

    private var cache: [String: DeviceHistory] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCache()
    }

    func history(for persistentSerial: String) -> DeviceHistory? {
        cache[persistentSerial]
    }

    func history(forIP ip: String) -> DeviceHistory? {
        cache.values.first { $0.lastKnownIP == ip }
    }

    func allHistory() -> [DeviceHistory] {
        Array(cache.values)
    }

    func save(_ history: DeviceHistory) {
        cache[history.persistentSerial] = history
        persist()
    }

    func setCustomName(_ name: String?, for persistentSerial: String) {
        if var history = cache[persistentSerial] {
            history.customName = name
            cache[persistentSerial] = history
        } else {
            cache[persistentSerial] = DeviceHistory(
                persistentSerial: persistentSerial,
                customName: name
            )
        }
        persist()
    }

    func remove(for persistentSerial: String) {
        cache.removeValue(forKey: persistentSerial)
        persist()
    }

    func clearAll() {
        cache.removeAll()
        persist()
    }

    // MARK: - Port Forward Presets

    func presets(for persistentSerial: String) -> [PortForwardPreset] {
        cache[persistentSerial]?.portForwardPresets ?? []
    }

    func setPresets(_ presets: [PortForwardPreset], for persistentSerial: String) {
        if var history = cache[persistentSerial] {
            history.portForwardPresets = presets
            cache[persistentSerial] = history
        } else {
            cache[persistentSerial] = DeviceHistory(
                persistentSerial: persistentSerial,
                portForwardPresets: presets
            )
        }
        persist()
    }

    func addPreset(_ preset: PortForwardPreset, for persistentSerial: String) {
        var current = presets(for: persistentSerial)
        current.append(preset)
        setPresets(current, for: persistentSerial)
    }

    func updatePreset(_ preset: PortForwardPreset, for persistentSerial: String) {
        var current = presets(for: persistentSerial)
        guard let idx = current.firstIndex(where: { $0.id == preset.id }) else { return }
        current[idx] = preset
        setPresets(current, for: persistentSerial)
    }

    func removePreset(id: UUID, for persistentSerial: String) {
        var current = presets(for: persistentSerial)
        current.removeAll { $0.id == id }
        setPresets(current, for: persistentSerial)
    }

    func devicesWithPresets() -> [DeviceHistory] {
        cache.values.filter { !$0.portForwardPresets.isEmpty }
    }

    private func loadCache() {
        guard let data = defaults.data(forKey: historyKey) else {
            return
        }

        do {
            let entries = try JSONDecoder().decode([DeviceHistory].self, from: data)
            cache = Dictionary(uniqueKeysWithValues: entries.map { ($0.persistentSerial, $0) })
        } catch {
            print("Failed to load device history: \(error)")
        }
    }

    private func persist() {
        do {
            let entries = Array(cache.values)
            let data = try JSONEncoder().encode(entries)
            defaults.set(data, forKey: historyKey)
        } catch {
            print("Failed to save device history: \(error)")
        }
    }
}
