import Foundation
import Combine

@MainActor
final class MirroringManager: ObservableObject {
    @Published private(set) var sessions: [String: MirroringSession] = [:]
    @Published private(set) var isAvailable: Bool = false

    private let adbService: ADBService
    private let deviceManager: DeviceManager
    private let settingsStore: SettingsStore

    private var availabilityTask: Task<Void, Never>?
    private var deviceWatcher: AnyCancellable?

    init(adbService: ADBService, deviceManager: DeviceManager, settingsStore: SettingsStore) {
        self.adbService = adbService
        self.deviceManager = deviceManager
        self.settingsStore = settingsStore

        availabilityTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let available = await self.adbService.isADBAvailable()
                await MainActor.run { self.isAvailable = available }
                try? await Task.sleep(for: .seconds(5))
            }
        }

        deviceWatcher = deviceManager.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.onDevicesChanged(devices)
            }
    }

    deinit {
        availabilityTask?.cancel()
        deviceWatcher?.cancel()
    }

    func session(for adbId: String) -> MirroringSession? {
        sessions[adbId]
    }

    @discardableResult
    func startSession(for device: Device, parameters: ServerParameters? = nil) async throws -> MirroringSession {
        guard isAvailable else { throw MirroringError.adbUnavailable }

        let key = device.bestAdbId

        if let existing = sessions[key] {
            return existing
        }

        var resolvedParams = parameters ?? ServerParameters()
        let appSettings = settingsStore.settings
        resolvedParams.maxSize = appSettings.mirroringMaxSize
        resolvedParams.maxFps = appSettings.mirroringMaxFps
        resolvedParams.stayAwake = appSettings.mirroringStayAwake
        resolvedParams.showTouches = appSettings.mirroringShowTouches
        resolvedParams.clipboardAutosync = appSettings.mirroringClipboardAutosync

        let session = MirroringSession(
            adbId: key,
            deviceName: device.displayName,
            adbService: adbService,
            parameters: resolvedParams,
            turnOffDisplayOnStart: appSettings.mirroringTurnOffDisplayOnStart,
            onFinished: { [weak self] finished in
                self?.remove(finished)
            }
        )
        sessions[key] = session

        await session.start()

        if case .error(let err) = session.state {
            sessions.removeValue(forKey: key)
            throw err
        }

        return session
    }

    func stopSession(adbId: String) async {
        guard let session = sessions[adbId] else { return }
        await session.stop()
    }

    func stopAll() async {
        let all = Array(sessions.values)
        for session in all {
            await session.stop()
        }
    }

    private func remove(_ session: MirroringSession) {
        if sessions[session.adbId] === session {
            sessions.removeValue(forKey: session.adbId)
        }
    }

    private func onDevicesChanged(_ devices: [Device]) {
        let connectedIds = Set(devices.filter { $0.state == .device }.flatMap { $0.allAdbIds })
        for (adbId, session) in sessions where !connectedIds.contains(adbId) {
            session.markDeviceGone()
        }
    }
}
