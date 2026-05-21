import Foundation

@MainActor
final class PortForwardAutoApplyManager: ObservableObject {
    @Published private(set) var lastErrorMessage: String?

    private let adbService: ADBService
    private let historyStore: DeviceHistoryStore
    private var appliedSerials: Set<String> = []
    private var watchTask: Task<Void, Never>?
    private var pendingApplyTasks: [String: Task<Void, Never>] = [:]

    init(adbService: ADBService, deviceManager: DeviceManager, historyStore: DeviceHistoryStore) {
        self.adbService = adbService
        self.historyStore = historyStore

        watchTask = Task { [weak self] in
            guard let self else { return }
            for await devices in deviceManager.$devices.values {
                await self.onDevicesChanged(devices)
            }
        }
    }

    deinit {
        watchTask?.cancel()
    }

    // MARK: - Public API

    func stop() async {
        watchTask?.cancel()
        watchTask = nil
        for task in pendingApplyTasks.values { task.cancel() }
        pendingApplyTasks.removeAll()
    }

    // MARK: - Private helpers

    private func onDevicesChanged(_ devices: [Device]) async {
        let connectedSerials = Set(
            devices.compactMap { $0.state == .device ? $0.persistentSerial : nil }
        )

        appliedSerials = appliedSerials.intersection(connectedSerials)

        let hasAutoApplyWork = connectedSerials.contains { serial in
            !historyStore.presets(for: serial).filter(\.autoApply).isEmpty
        }
        if !hasAutoApplyWork {
            lastErrorMessage = nil
        }

        for device in devices where device.state == .device {
            guard let serial = device.persistentSerial,
                  !appliedSerials.contains(serial) else { continue }

            let presets = historyStore.presets(for: serial).filter(\.autoApply)

            guard !presets.isEmpty else { continue }

            appliedSerials.insert(serial)

            let task = Task { [weak self] in
                defer { Task { [weak self] in self?.pendingApplyTasks[serial] = nil } }
                await self?.apply(presets, on: device)
            }
            pendingApplyTasks[serial] = task
        }
    }

    private func apply(_ presets: [PortForwardPreset], on device: Device) async {
        let adbId = device.bestAdbId
        var errors: [String] = []
        for preset in presets {
            guard (1...65535).contains(preset.localPort), (1...65535).contains(preset.remotePort) else {
                print(
                    "[PortForwardAutoApply] skipping invalid preset \(preset.displayName) (\(preset.localPort) → \(preset.remotePort))"
                )
                continue
            }
            do {
                try await adbService.createReverseForward(
                    localPort: preset.localPort,
                    remotePort: preset.remotePort,
                    deviceId: adbId
                )
                print("[PortForwardAutoApply] applied \(preset.displayName) on \(adbId)")
            } catch let error as ADBError {
                print("[PortForwardAutoApply] failed \(preset.displayName): \(error.localizedDescription)")
                errors.append("\(preset.displayName): \(error.localizedDescription)")
            } catch {
                print("[PortForwardAutoApply] failed \(preset.displayName): \(error.localizedDescription)")
                errors.append("\(preset.displayName): \(error.localizedDescription)")
            }
        }
        lastErrorMessage = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }
}
