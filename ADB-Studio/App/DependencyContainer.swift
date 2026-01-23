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

        setupSettingsObserver()
    }

    func start() {
        deviceManager.startMonitoring()
    }

    func stop() {
        deviceManager.stopMonitoring()
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
