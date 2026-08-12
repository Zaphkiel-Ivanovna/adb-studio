import Foundation
import Combine

@MainActor
final class DependencyContainer: ObservableObject {
    let settingsStore: SettingsStore
    let crashReporting: CrashReportingService
    let shellExecutor: ShellExecuting
    let adbService: ADBServiceImpl
    let deviceIdentifier: DeviceIdentifier
    let historyStore: DeviceHistoryStore
    let screenshotService: ScreenshotService
    let deviceManager: DeviceManager
    let discoveryService: DeviceDiscoveryService
    let updateService: UpdateService
    let mirroringManager: MirroringManager
    let portForwardAutoApplyManager: PortForwardAutoApplyManager

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.settingsStore = SettingsStore()

        // Crash reporting is constructed first and started before any shell/device work, so the
        // native crash handlers cover the rest of init (e.g. the ShellExecutor SIGABRT class).
        let installationID = settingsStore.settings.crashReportingInstallationID ?? UUID().uuidString
        if settingsStore.settings.crashReportingInstallationID == nil {
            settingsStore.update { $0.crashReportingInstallationID = installationID }
        }
        self.crashReporting = CrashReportingServiceImpl(installationID: installationID)
        crashReporting.start(consent: settingsStore.settings.crashReportingConsent)

        self.shellExecutor = ShellExecutor(crashReporting: crashReporting)
        self.adbService = ADBServiceImpl(shell: shellExecutor, settingsStore: settingsStore)
        self.deviceIdentifier = DeviceIdentifier(adbService: adbService)
        self.historyStore = DeviceHistoryStore()
        self.screenshotService = ScreenshotService(adbService: adbService)
        self.deviceManager = DeviceManager(
            adbService: adbService,
            deviceIdentifier: deviceIdentifier,
            historyStore: historyStore,
            settingsStore: settingsStore,
            crashReporting: crashReporting
        )
        self.discoveryService = DeviceDiscoveryService(historyStore: historyStore)
        self.updateService = UpdateService()
        self.mirroringManager = MirroringManager(
            adbService: adbService,
            deviceManager: deviceManager,
            settingsStore: settingsStore,
            crashReporting: crashReporting
        )
        self.portForwardAutoApplyManager = PortForwardAutoApplyManager(
            adbService: adbService,
            deviceManager: deviceManager,
            historyStore: historyStore
        )

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
        // Flush first so queued telemetry drains even if a later teardown step stalls.
        await crashReporting.flush(timeout: 3)
        await mirroringManager.stopAll()
        await portForwardAutoApplyManager.stop()
    }

    private func setupSettingsObserver() {
        settingsStore.settingsChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.deviceManager.updateRefreshInterval(settings.refreshInterval)
                self?.crashReporting.setConsent(settings.crashReportingConsent)
            }
            .store(in: &cancellables)
    }
}
