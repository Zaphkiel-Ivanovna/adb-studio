import Foundation
import Combine

@MainActor
final class InstalledAppsViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isLoading = false
    @Published var searchText = "" {
        didSet { debounceSearch() }
    }
    @Published var filter: AppFilter = .user {
        didSet { updateFilteredApps() }
    }
    @Published var sortOrder: AppSortOrder = .name {
        didSet { updateFilteredApps() }
    }
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var appBeingActioned: String?
    @Published var showUninstallConfirmation = false
    @Published var appToUninstall: InstalledApp?
    @Published var keepDataOnUninstall = false

    @Published private(set) var isSelectionMode = false
    @Published private(set) var selectedPackageNames: Set<String> = []

    @Published var showBulkUninstallSheet = false
    @Published var bulkKeepData = false
    @Published private(set) var bulkPhase: BulkUninstallPhase = .confirming
    @Published private(set) var isBulkStopRequested = false

    // Cached filtered results for performance
    @Published private(set) var filteredApps: [InstalledApp] = []
    private var debouncedSearchText = ""
    private var searchDebounceTask: Task<Void, Never>?
    private var successMessageTask: Task<Void, Never>?

    private let deviceId: String
    private let adbService: ADBService
    private var loadedDetails: Set<String> = []
    private var isLoadingDetails: Set<String> = []

    private var bulkUninstallTask: Task<Void, Never>?

    deinit {
        bulkUninstallTask?.cancel()
    }

    private func debounceSearch() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            debouncedSearchText = searchText
            updateFilteredApps()
        }
    }

    private func updateFilteredApps() {
        var result = apps

        switch filter {
        case .all:
            break
        case .user:
            result = result.filter { !$0.isSystemApp }
        case .system:
            result = result.filter { $0.isSystemApp }
        case .disabled:
            result = result.filter { !$0.isEnabled }
        }

        if !debouncedSearchText.isEmpty {
            let query = debouncedSearchText.lowercased()
            result = result.filter {
                $0.packageName.lowercased().contains(query) ||
                ($0.displayName?.lowercased().contains(query) ?? false)
            }
        }

        result.sort { app1, app2 in
            switch sortOrder {
            case .name:
                return app1.effectiveDisplayName.localizedCaseInsensitiveCompare(app2.effectiveDisplayName) == .orderedAscending
            case .packageName:
                return app1.packageName.localizedCaseInsensitiveCompare(app2.packageName) == .orderedAscending
            case .updateTime:
                let date1 = app1.updateTime ?? .distantPast
                let date2 = app2.updateTime ?? .distantPast
                return date1 > date2
            case .installTime:
                let date1 = app1.installTime ?? .distantPast
                let date2 = app2.installTime ?? .distantPast
                return date1 > date2
            }
        }

        filteredApps = result
    }

    var appCount: String {
        let filtered = filteredApps.count
        let total = apps.count
        if filtered == total {
            return "\(total) apps"
        }
        return "\(filtered) of \(total) apps"
    }

    init(deviceId: String, adbService: ADBService) {
        self.deviceId = deviceId
        self.adbService = adbService
    }

    func loadApps() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        loadedDetails.removeAll()
        isLoadingDetails.removeAll()

        do {
            // Phase 1: Get all package names quickly
            let allPackages = try await adbService.listPackages(deviceId: deviceId, filter: .all)
            let thirdPartyPackages = Set(try await adbService.listPackages(deviceId: deviceId, filter: .thirdParty))
            let disabledPackages = Set(try await adbService.listPackages(deviceId: deviceId, filter: .disabled))

            // Create basic app entries
            apps = allPackages.map { packageName in
                InstalledApp(
                    packageName: packageName,
                    displayName: nil,
                    versionName: nil,
                    versionCode: nil,
                    installTime: nil,
                    updateTime: nil,
                    isSystemApp: !thirdPartyPackages.contains(packageName),
                    isEnabled: !disabledPackages.contains(packageName)
                )
            }
            selectedPackageNames.formIntersection(apps.map(\.packageName))
            updateFilteredApps()
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadDetailsIfNeeded(for app: InstalledApp) {
        let packageName = app.packageName
        guard !loadedDetails.contains(packageName),
              !isLoadingDetails.contains(packageName) else { return }

        isLoadingDetails.insert(packageName)

        Task { @MainActor in
            defer { isLoadingDetails.remove(packageName) }

            do {
                let details = try await adbService.getPackageInfo(packageName: packageName, deviceId: deviceId)

                // Re-verify the app still exists and update atomically
                if let index = apps.firstIndex(where: { $0.packageName == packageName }),
                   index < apps.count,
                   apps[index].packageName == packageName {
                    apps[index].versionName = details.versionName
                    apps[index].versionCode = details.versionCode
                    apps[index].installTime = details.installTime
                    apps[index].updateTime = details.updateTime
                    apps[index].isEnabled = details.isEnabled
                }

                loadedDetails.insert(packageName)
            } catch {
                // Silently fail for details loading
            }
        }
    }

    func performAction(_ action: AppAction, on app: InstalledApp) async {
        appBeingActioned = app.packageName
        errorMessage = nil

        do {
            switch action {
            case .launch:
                try await adbService.launchApp(packageName: app.packageName, deviceId: deviceId)
                showSuccess("Launched \(app.effectiveDisplayName)")

            case .forceStop:
                try await adbService.forceStopApp(packageName: app.packageName, deviceId: deviceId)
                showSuccess("Stopped \(app.effectiveDisplayName)")

            case .uninstall:
                try await uninstall(app, keepData: false)
                showSuccess("Uninstalled \(app.effectiveDisplayName)")

            case .uninstallKeepData:
                try await uninstall(app, keepData: true)
                showSuccess("Uninstalled \(app.effectiveDisplayName) (data kept)")

            case .disable:
                try await adbService.disableApp(packageName: app.packageName, deviceId: deviceId)
                if let index = apps.firstIndex(where: { $0.packageName == app.packageName }),
                   index < apps.count {
                    apps[index].isEnabled = false
                    updateFilteredApps()
                }
                showSuccess("Disabled \(app.effectiveDisplayName)")

            case .enable:
                try await adbService.enableApp(packageName: app.packageName, deviceId: deviceId)
                if let index = apps.firstIndex(where: { $0.packageName == app.packageName }),
                   index < apps.count {
                    apps[index].isEnabled = true
                    updateFilteredApps()
                }
                showSuccess("Enabled \(app.effectiveDisplayName)")

            case .openSettings:
                try await adbService.openAppSettings(packageName: app.packageName, deviceId: deviceId)
            }
        } catch let error as ADBError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        appBeingActioned = nil
    }

    func requestUninstall(_ app: InstalledApp, keepData: Bool) {
        appToUninstall = app
        keepDataOnUninstall = keepData
        showUninstallConfirmation = true
    }

    func confirmUninstall() async {
        guard let app = appToUninstall else { return }
        showUninstallConfirmation = false

        await performAction(keepDataOnUninstall ? .uninstallKeepData : .uninstall, on: app)

        appToUninstall = nil
        keepDataOnUninstall = false
    }

    func cancelUninstall() {
        showUninstallConfirmation = false
        appToUninstall = nil
        keepDataOnUninstall = false
    }

    // MARK: - Selection

    var selectedApps: [InstalledApp] {
        apps
            .filter { selectedPackageNames.contains($0.packageName) }
            .sorted { $0.effectiveDisplayName.localizedCaseInsensitiveCompare($1.effectiveDisplayName) == .orderedAscending }
    }

    var selectedSystemAppCount: Int {
        apps.filter { selectedPackageNames.contains($0.packageName) && $0.isSystemApp }.count
    }

    var areAllFilteredSelected: Bool {
        !filteredApps.isEmpty && filteredApps.allSatisfy { selectedPackageNames.contains($0.packageName) }
    }

    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedPackageNames.removeAll()
        }
    }

    func toggleSelection(for app: InstalledApp) {
        if selectedPackageNames.contains(app.packageName) {
            selectedPackageNames.remove(app.packageName)
        } else {
            selectedPackageNames.insert(app.packageName)
        }
    }

    func selectAllFiltered() {
        selectedPackageNames.formUnion(filteredApps.map(\.packageName))
    }

    func deselectAll() {
        selectedPackageNames.removeAll()
    }

    // MARK: - Bulk Uninstall

    var isBulkUninstalling: Bool {
        if case .running = bulkPhase { return true }
        return false
    }

    func requestBulkUninstall() {
        guard !selectedPackageNames.isEmpty else { return }
        bulkPhase = .confirming
        bulkKeepData = false
        isBulkStopRequested = false
        showBulkUninstallSheet = true
    }

    func confirmBulkUninstall() {
        let targets = selectedApps
        guard let firstApp = targets.first, bulkUninstallTask == nil else { return }

        let keepData = bulkKeepData
        isBulkStopRequested = false
        errorMessage = nil
        bulkPhase = .running(current: 1, total: targets.count, appName: firstApp.effectiveDisplayName)
        bulkUninstallTask = Task { [weak self] in
            await self?.runBulkUninstall(targets, keepData: keepData)
        }
    }

    func requestBulkUninstallStop() {
        isBulkStopRequested = true
    }

    func dismissBulkUninstall() {
        if case .finished(_, let failures, let skipped) = bulkPhase, failures.isEmpty, skipped == 0 {
            isSelectionMode = false
            selectedPackageNames.removeAll()
        }
        bulkKeepData = false
        isBulkStopRequested = false
    }

    private func runBulkUninstall(_ targets: [InstalledApp], keepData: Bool) async {
        var failures: [BulkUninstallFailure] = []
        var succeeded = 0

        for (index, app) in targets.enumerated() {
            if isBulkStopRequested || Task.isCancelled { break }
            bulkPhase = .running(current: index + 1, total: targets.count, appName: app.effectiveDisplayName)

            do {
                try await uninstall(app, keepData: keepData)
                succeeded += 1
            } catch let error as ADBError {
                failures.append(failure(for: app, message: error.localizedDescription))
                if error.isDeviceUnreachable { break }
            } catch {
                failures.append(failure(for: app, message: error.localizedDescription))
            }
        }

        bulkPhase = .finished(
            succeeded: succeeded,
            failures: failures,
            skipped: targets.count - succeeded - failures.count
        )
        bulkUninstallTask = nil
    }

    // MARK: - Private Helpers

    private func uninstall(_ app: InstalledApp, keepData: Bool) async throws {
        try await adbService.uninstallApp(packageName: app.packageName, keepData: keepData, deviceId: deviceId)
        removeUninstalledApp(app.packageName)
    }

    private func failure(for app: InstalledApp, message: String) -> BulkUninstallFailure {
        BulkUninstallFailure(
            packageName: app.packageName,
            displayName: app.effectiveDisplayName,
            message: message
        )
    }

    private func removeUninstalledApp(_ packageName: String) {
        apps.removeAll { $0.packageName == packageName }
        selectedPackageNames.remove(packageName)
        loadedDetails.remove(packageName)
        updateFilteredApps()
    }

    private func showSuccess(_ message: String) {
        successMessageTask?.cancel()
        successMessage = message
        successMessageTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            if successMessage == message {
                successMessage = nil
            }
        }
    }
}
