import Foundation
import Combine

@MainActor
final class DependencyContainer: ObservableObject {
    let settingsStore: SettingsStore
    let shellExecutor: ShellExecuting
    let adbService: ADBServiceImpl
    let deviceIdentifier: DeviceIdentifier
    let historyStore: DeviceHistoryStore
    let screenshotService: ScreenshotService
    let deviceManager: DeviceManager
    let discoveryService: DeviceDiscoveryService
    let updateService: UpdateService
    let mirroringManager: MirroringManager

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.settingsStore = SettingsStore()
        self.shellExecutor = ShellExecutor()
        self.adbService = ADBServiceImpl(shell: shellExecutor, settingsStore: settingsStore)
        self.deviceIdentifier = DeviceIdentifier(adbService: adbService)
        self.historyStore = DeviceHistoryStore()
        self.screenshotService = ScreenshotService(adbService: adbService)
        self.deviceManager = DeviceManager(
            adbService: adbService,
            deviceIdentifier: deviceIdentifier,
            historyStore: historyStore,
            settingsStore: settingsStore
        )
        self.discoveryService = DeviceDiscoveryService(historyStore: historyStore)
        self.updateService = UpdateService()
        self.mirroringManager = MirroringManager(adbService: adbService, deviceManager: deviceManager, settingsStore: settingsStore)

        setupSettingsObserver()
    }

    func start() {
        deviceManager.startMonitoring()

        if settingsStore.settings.checkForUpdatesOnLaunch {
            Task {
                await updateService.checkForUpdates()
            }
        }
    }

    func stop() {
        deviceManager.stopMonitoring()
    }

    func shutdown() async {
        deviceManager.stopMonitoring()
        await mirroringManager.stopAll()
    }

    private func setupSettingsObserver() {
        settingsStore.settingsChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.deviceManager.updateRefreshInterval(settings.refreshInterval)
            }
            .store(in: &cancellables)
    }
}
