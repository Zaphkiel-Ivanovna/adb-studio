import Foundation

@MainActor
final class DependencyContainer: ObservableObject {
    let shellExecutor: ShellExecuting
    let adbService: ADBService
    let deviceIdentifier: DeviceIdentifier
    let historyStore: DeviceHistoryStore
    let screenshotService: ScreenshotService
    let deviceManager: DeviceManager

    init() {
        self.shellExecutor = ShellExecutor()
        self.adbService = ADBServiceImpl(shell: shellExecutor)
        self.deviceIdentifier = DeviceIdentifier(adbService: adbService)
        self.historyStore = DeviceHistoryStore()
        self.screenshotService = ScreenshotService(adbService: adbService)
        self.deviceManager = DeviceManager(
            adbService: adbService,
            deviceIdentifier: deviceIdentifier,
            historyStore: historyStore
        )
    }

    func start() {
        deviceManager.startMonitoring()
    }

    func stop() {
        deviceManager.stopMonitoring()
    }
}
