import Foundation
import Combine

@MainActor
final class DeviceManager: ObservableObject {
    @Published private(set) var devices: [Device] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: ADBError?
    @Published private(set) var isADBAvailable = false
    @Published private(set) var hasCheckedADB = false

    private let adbService: ADBService
    private let deviceIdentifier: DeviceIdentifier
    private let historyStore: DeviceHistoryStore

    private var refreshTask: Task<Void, Never>?
    private var autoRefreshTask: Task<Void, Never>?

    init(
        adbService: ADBService,
        deviceIdentifier: DeviceIdentifier,
        historyStore: DeviceHistoryStore
    ) {
        self.adbService = adbService
        self.deviceIdentifier = deviceIdentifier
        self.historyStore = historyStore
    }

    func startMonitoring(interval: TimeInterval = 3.0) {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            await checkADBAvailability()

            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopMonitoring() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    func checkADBAvailability() async {
        isADBAvailable = await adbService.isADBAvailable()
        hasCheckedADB = true
    }

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        lastError = nil

        do {
            var newDevices = try await adbService.listDevices()

            newDevices = await withTaskGroup(of: (Int, Device).self) { group in
                for (index, device) in newDevices.enumerated() {
                    group.addTask {
                        let fullDevice = await self.deviceIdentifier.fetchDeviceProperties(for: device)
                        return (index, fullDevice)
                    }
                }

                var results = newDevices
                for await (index, device) in group {
                    results[index] = device
                }
                return results
            }

            newDevices = mergeWithHistory(newDevices)
            updateHistory(newDevices)
            devices = deduplicateDevices(newDevices)

        } catch let error as ADBError {
            lastError = error
        } catch {
            lastError = .commandFailed("refresh", -1)
        }

        isRefreshing = false
    }

    func connect(to address: String) async throws {
        try await adbService.connect(to: address)
        await refresh()
    }

    func disconnect(from device: Device) async throws {
        guard let serial = device.persistentSerial else {
            if device.connection.isWiFiBased {
                try await adbService.disconnect(from: device.adbId)
            }
            await refresh()
            return
        }

        let allDevices = try await adbService.listDevices()
        let enrichedDevices = await withTaskGroup(of: (Int, Device).self) { group in
            for (index, dev) in allDevices.enumerated() {
                group.addTask {
                    let fullDevice = await self.deviceIdentifier.fetchDeviceProperties(for: dev)
                    return (index, fullDevice)
                }
            }
            var results = allDevices
            for await (index, dev) in group {
                results[index] = dev
            }
            return results
        }

        for dev in enrichedDevices where dev.persistentSerial == serial && dev.connection.isWiFiBased {
            try? await adbService.disconnect(from: dev.adbId)
        }

        await refresh()
    }

    func setCustomName(_ name: String?, for device: Device) {
        guard let serial = device.persistentSerial else { return }

        historyStore.setCustomName(name, for: serial)

        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].customName = name
        }
    }

    func device(withId id: String) -> Device? {
        devices.first { $0.id == id }
    }

    func clearError() {
        lastError = nil
    }

    private func mergeWithHistory(_ devices: [Device]) -> [Device] {
        devices.map { device in
            var updated = device
            if let serial = device.persistentSerial,
               let history = historyStore.history(for: serial) {
                updated.customName = history.customName
            }
            return updated
        }
    }

    private func updateHistory(_ devices: [Device]) {
        for device in devices where device.state == .device {
            guard let serial = device.persistentSerial else { continue }

            var history = historyStore.history(for: serial) ?? DeviceHistory(persistentSerial: serial)

            history.lastSeen = Date()
            history.model = device.model ?? history.model
            history.brand = device.brand ?? history.brand

            if device.connection.isWiFiBased {
                history.lastKnownIP = device.connection.ipAddress
                history.lastKnownPort = device.connection.port
            }

            historyStore.save(history)
        }
    }

    private func deduplicateDevices(_ devices: [Device]) -> [Device] {
        var seen: [String: Device] = [:]

        for var device in devices {
            // Offline WiFi devices can't fetch serial from ADB, so lookup from history by IP
            if device.persistentSerial == nil,
               device.connection.isWiFiBased,
               let ip = device.connection.ipAddress,
               let history = historyStore.history(forIP: ip) {
                device.persistentSerial = history.persistentSerial
                device.model = device.model ?? history.model
                device.brand = device.brand ?? history.brand
                device.customName = device.customName ?? history.customName
            }

            let key = device.persistentSerial ?? device.adbId

            if var existing = seen[key] {
                if existing.adbId != device.adbId && !existing.additionalAdbIds.contains(device.adbId) {
                    existing.additionalAdbIds.append(device.adbId)
                }
                if existing.connection != device.connection && !existing.additionalConnections.contains(device.connection) {
                    existing.additionalConnections.append(device.connection)
                }

                if device.state == .device && existing.state != .device {
                    let allConnections = existing.additionalConnections + [existing.connection]
                    let allAdbIds = existing.additionalAdbIds + [existing.adbId]
                    let newAdbId = device.adbId
                    existing = device
                    existing.additionalConnections = allConnections.filter { $0 != device.connection }
                    existing.additionalAdbIds = allAdbIds.filter { $0 != newAdbId }
                } else if device.connection.type == .usb && existing.connection.type != .usb {
                    let oldPrimaryConnection = existing.connection
                    let oldPrimaryAdbId = existing.adbId
                    existing.additionalConnections = existing.additionalConnections.filter { $0 != device.connection }
                    existing.additionalAdbIds = existing.additionalAdbIds.filter { $0 != device.adbId }
                    if !existing.additionalConnections.contains(oldPrimaryConnection) {
                        existing.additionalConnections.append(oldPrimaryConnection)
                        existing.additionalAdbIds.append(oldPrimaryAdbId)
                    }
                }

                existing.model = existing.model ?? device.model
                existing.brand = existing.brand ?? device.brand
                existing.androidVersion = existing.androidVersion ?? device.androidVersion
                existing.sdkVersion = existing.sdkVersion ?? device.sdkVersion

                seen[key] = existing
            } else {
                seen[key] = device
            }
        }

        return Array(seen.values).sorted { $0.displayName < $1.displayName }
    }
}
