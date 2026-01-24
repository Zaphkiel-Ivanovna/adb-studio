import Foundation

final class ADBServiceImpl: ADBService {
    private let shell: ShellExecuting
    private let settingsStore: SettingsStore
    private var cachedADBPath: String?

    init(shell: ShellExecuting = ShellExecutor(), settingsStore: SettingsStore) {
        self.shell = shell
        self.settingsStore = settingsStore
        self.cachedADBPath = ShellExecutor.findADBPath()
    }

    private func getADBPath() throws -> String {
        if let customPath = settingsStore.settings.effectiveADBPath {
            return customPath
        }
        if let path = cachedADBPath { return path }
        if let path = ShellExecutor.findADBPath() {
            cachedADBPath = path
            return path
        }
        throw ADBError.adbNotFound
    }

    private func adb(_ arguments: [String], timeout: TimeInterval = 30) async throws -> ShellResult {
        let path = try getADBPath()
        return try await shell.execute(path, arguments: arguments, timeout: timeout)
    }

    private func adb(deviceId: String, _ arguments: [String], timeout: TimeInterval = 30) async throws -> ShellResult {
        return try await adb(["-s", deviceId] + arguments, timeout: timeout)
    }

    func isADBAvailable() async -> Bool {
        do {
            let _ = try getADBPath()
            let result = try await adb(["version"])
            return result.isSuccess
        } catch {
            return false
        }
    }

    func listDevices() async throws -> [Device] {
        let result = try await adb(["devices", "-l"])
        guard result.isSuccess else {
            throw ADBError.commandFailed("devices -l", result.exitCode)
        }
        return ADBOutputParser.parseDevicesList(result.output)
    }

    func connect(to address: String) async throws {
        let result = try await adb(["connect", address], timeout: 10)

        if result.output.contains("connected to") || result.output.contains("already connected") {
            return
        }

        if result.output.contains("failed") || result.output.contains("unable") {
            throw ADBError.connectionFailed(result.output)
        }

        if !result.isSuccess {
            throw ADBError.connectionFailed(result.combinedOutput)
        }
    }

    func disconnect(from address: String) async throws {
        let result = try await adb(["disconnect", address])
        if !result.isSuccess && !result.output.contains("disconnected") {
            throw ADBError.commandFailed("disconnect", result.exitCode)
        }
    }

    func pair(address: String, code: String) async throws {
        let result = try await adb(["pair", address, code], timeout: 30)
        let output = result.combinedOutput

        if output.contains("Successfully paired") {
            return
        }

        // Protocol fault = code expired or connection dropped
        if output.contains("protocol fault") || output.contains("couldn't read status") {
            throw ADBError.pairingFailed("Pairing code expired or connection interrupted. Please generate a new code on your device and try again.")
        }

        if output.contains("wrong password") || output.contains("incorrect") {
            throw ADBError.pairingFailed("Incorrect pairing code. Please check the code and try again.")
        }

        if output.contains("Connection refused") {
            throw ADBError.pairingFailed("Connection refused. Ensure Wireless Debugging is enabled and the device is in pairing mode.")
        }

        if output.contains("No route to host") || output.contains("Network is unreachable") {
            throw ADBError.pairingFailed("Cannot reach device. Ensure both devices are on the same network.")
        }

        if output.contains("Failed") || output.contains("failed") || output.contains("error") {
            throw ADBError.pairingFailed(output)
        }

        if !result.isSuccess {
            throw ADBError.pairingFailed(output)
        }
    }

    func getProperty(_ property: String, deviceId: String) async throws -> String {
        let result = try await adb(deviceId: deviceId, ["shell", "getprop", property])
        if !result.isSuccess {
            throw ADBError.commandFailed("getprop \(property)", result.exitCode)
        }
        return result.output
    }

    func getProperties(_ properties: [String], deviceId: String) async throws -> [String: String] {
        var results: [String: String] = [:]

        try await withThrowingTaskGroup(of: (String, String).self) { group in
            for property in properties {
                group.addTask {
                    let value = try await self.getProperty(property, deviceId: deviceId)
                    return (property, value)
                }
            }
            for try await (property, value) in group {
                results[property] = value
            }
        }

        return results
    }

    func shell(_ command: String, deviceId: String) async throws -> String {
        let result = try await adb(deviceId: deviceId, ["shell", command])
        if !result.isSuccess {
            throw ADBError.commandFailed("shell \(command)", result.exitCode)
        }
        return result.output
    }

    func takeScreenshot(deviceId: String) async throws -> Data {
        let path = try getADBPath()
        let data = try await shell.executeRaw(path, arguments: ["-s", deviceId, "exec-out", "screencap", "-p"], timeout: 30)

        if data.isEmpty {
            throw ADBError.commandFailed("screencap", -1)
        }

        return data
    }

    func inputText(_ text: String, deviceId: String) async throws {
        // Escape special shell chars for `input text`
        let escaped = text
            .replacingOccurrences(of: " ", with: "%s")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "&", with: "\\&")
            .replacingOccurrences(of: "<", with: "\\<")
            .replacingOccurrences(of: ">", with: "\\>")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")

        let result = try await adb(deviceId: deviceId, ["shell", "input", "text", escaped])
        if !result.isSuccess {
            throw ADBError.commandFailed("input text", result.exitCode)
        }
    }

    func inputKeyEvent(_ keyCode: Int, deviceId: String) async throws {
        let result = try await adb(deviceId: deviceId, ["shell", "input", "keyevent", String(keyCode)])
        if !result.isSuccess {
            throw ADBError.commandFailed("input keyevent \(keyCode)", result.exitCode)
        }
    }

    func listReverseForwards(deviceId: String) async throws -> [PortForward] {
        let result = try await adb(deviceId: deviceId, ["reverse", "--list"])
        if !result.isSuccess && !result.output.isEmpty {
            throw ADBError.commandFailed("reverse --list", result.exitCode)
        }
        return ADBOutputParser.parseReverseList(result.output, deviceId: deviceId)
    }

    func createReverseForward(localPort: Int, remotePort: Int, deviceId: String) async throws {
        let result = try await adb(deviceId: deviceId, ["reverse", "tcp:\(localPort)", "tcp:\(remotePort)"])
        if !result.isSuccess {
            throw ADBError.commandFailed("reverse tcp:\(localPort) tcp:\(remotePort)", result.exitCode)
        }
    }

    func removeReverseForward(localPort: Int, deviceId: String) async throws {
        let result = try await adb(deviceId: deviceId, ["reverse", "--remove", "tcp:\(localPort)"])
        if !result.isSuccess {
            throw ADBError.commandFailed("reverse --remove tcp:\(localPort)", result.exitCode)
        }
    }

    func removeAllReverseForwards(deviceId: String) async throws {
        let result = try await adb(deviceId: deviceId, ["reverse", "--remove-all"])
        if !result.isSuccess {
            throw ADBError.commandFailed("reverse --remove-all", result.exitCode)
        }
    }

    func enableTcpip(port: Int, deviceId: String) async throws {
        let result = try await adb(deviceId: deviceId, ["tcpip", String(port)])
        if !result.isSuccess {
            throw ADBError.commandFailed("tcpip \(port)", result.exitCode)
        }
    }

    func installAPK(path: URL, deviceId: String, onStart: @escaping (APKInstallHandle) -> Void, onProgress: @escaping (String) -> Void) async throws {
        let adbPath = try getADBPath()
        let process = Process()
        let handle = APKInstallHandle()
        handle.setProcess(process)
        let timeout: TimeInterval = 300

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: adbPath)
            process.arguments = ["-s", deviceId, "install", "-r", path.path]
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            var outputData = Data()
            var errorData = Data()
            var hasResumed = false
            let resumeLock = NSLock()

            func safeResume(with result: Result<Void, Error>) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let timeoutWork = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                    safeResume(with: .failure(ADBError.timeout))
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

            outputPipe.fileHandleForReading.readabilityHandler = { _ in
                let data = outputPipe.fileHandleForReading.availableData
                if !data.isEmpty {
                    outputData.append(data)
                    if let str = String(data: data, encoding: .utf8) {
                        let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
                        for line in lines {
                            DispatchQueue.main.async { onProgress(line) }
                        }
                    }
                }
            }

            errorPipe.fileHandleForReading.readabilityHandler = { _ in
                let data = errorPipe.fileHandleForReading.availableData
                if !data.isEmpty {
                    errorData.append(data)
                }
            }

            process.terminationHandler = { proc in
                timeoutWork.cancel()
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                if proc.terminationReason == .uncaughtSignal {
                    safeResume(with: .failure(CancellationError()))
                    return
                }

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                if proc.terminationStatus != 0 || output.contains("Failure") || errorOutput.contains("Failure") {
                    let message = Self.parseInstallError(output: output, errorOutput: errorOutput)
                    safeResume(with: .failure(ADBError.installFailed(message)))
                } else {
                    safeResume(with: .success(()))
                }
            }

            do {
                try process.run()
                DispatchQueue.main.async { onStart(handle) }
            } catch {
                timeoutWork.cancel()
                safeResume(with: .failure(ADBError.commandFailed("install", -1)))
            }
        }
    }

    private static func parseInstallError(output: String, errorOutput: String) -> String {
        let combined = output + errorOutput

        if combined.contains("INSTALL_FAILED_ALREADY_EXISTS") {
            return "App already installed with different signature"
        }
        if combined.contains("INSTALL_FAILED_INVALID_APK") {
            return "Invalid APK file"
        }
        if combined.contains("INSTALL_FAILED_INSUFFICIENT_STORAGE") {
            return "Insufficient storage on device"
        }
        if combined.contains("INSTALL_FAILED_VERSION_DOWNGRADE") {
            return "Cannot downgrade app version"
        }
        if combined.contains("INSTALL_PARSE_FAILED_NO_CERTIFICATES") {
            return "APK is not signed"
        }
        if combined.contains("INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
            return "Update incompatible with existing app"
        }
        if combined.contains("INSTALL_FAILED_NO_MATCHING_ABIS") {
            return "APK not compatible with device architecture"
        }

        if let range = combined.range(of: "Failure \\[([^\\]]+)\\]", options: .regularExpression) {
            return String(combined[range])
        }

        if !errorOutput.isEmpty {
            return errorOutput
        }
        if !output.isEmpty {
            return output
        }
        return "Unknown installation error"
    }

    // MARK: - App Management

    /// Validates that a package name follows Android naming conventions
    /// Prevents command injection via malformed package names
    private func validatePackageName(_ packageName: String) throws {
        // Android package names: letters, digits, underscores, dots
        // Must start with a letter, minimum 2 segments separated by dots
        let pattern = "^[a-zA-Z][a-zA-Z0-9_]*(\\.[a-zA-Z][a-zA-Z0-9_]*)+$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              regex.firstMatch(in: packageName, range: NSRange(packageName.startIndex..., in: packageName)) != nil,
              packageName.count <= 255 else {
            throw ADBError.appNotFound(packageName)
        }
    }

    func listPackages(deviceId: String, filter: AppListFilter) async throws -> [String] {
        var args = ["pm", "list", "packages"]

        switch filter {
        case .all:
            break
        case .thirdParty:
            args.append("-3")
        case .system:
            args.append("-s")
        case .disabled:
            args.append("-d")
        }

        let result = try await adb(deviceId: deviceId, ["shell"] + args)
        if !result.isSuccess {
            throw ADBError.commandFailed("pm list packages", result.exitCode)
        }

        return ADBOutputParser.parsePackageList(result.output)
    }

    func getPackageInfo(packageName: String, deviceId: String) async throws -> InstalledApp {
        try validatePackageName(packageName)
        let result = try await adb(deviceId: deviceId, ["shell", "dumpsys", "package", packageName], timeout: 10)
        if !result.isSuccess {
            throw ADBError.commandFailed("dumpsys package \(packageName)", result.exitCode)
        }

        if result.output.contains("Unable to find package:") {
            throw ADBError.appNotFound(packageName)
        }

        return ADBOutputParser.parsePackageInfo(result.output, packageName: packageName)
    }

    func launchApp(packageName: String, deviceId: String) async throws {
        try validatePackageName(packageName)
        let result = try await adb(deviceId: deviceId, ["shell", "monkey", "-p", packageName, "-c", "android.intent.category.LAUNCHER", "1"])

        if !result.isSuccess || result.output.contains("No activities found") {
            throw ADBError.appActionFailed("Launch", "No launchable activity found for \(packageName)")
        }
    }

    func forceStopApp(packageName: String, deviceId: String) async throws {
        try validatePackageName(packageName)
        let result = try await adb(deviceId: deviceId, ["shell", "am", "force-stop", packageName])
        if !result.isSuccess {
            throw ADBError.appActionFailed("Force Stop", result.combinedOutput)
        }
    }

    func uninstallApp(packageName: String, keepData: Bool, deviceId: String) async throws {
        try validatePackageName(packageName)
        var args = ["uninstall"]
        if keepData {
            args.append("-k")
        }
        args.append(packageName)

        let result = try await adb(deviceId: deviceId, args, timeout: 60)

        if result.output.contains("Success") {
            return
        }

        if result.output.contains("Failure") || result.errorOutput.contains("Failure") {
            let message = result.combinedOutput.contains("[DELETE_FAILED_INTERNAL_ERROR]")
                ? "Cannot uninstall system app"
                : result.combinedOutput
            throw ADBError.uninstallFailed(message)
        }

        if !result.isSuccess {
            throw ADBError.uninstallFailed(result.combinedOutput)
        }
    }

    func disableApp(packageName: String, deviceId: String) async throws {
        try validatePackageName(packageName)
        let result = try await adb(deviceId: deviceId, ["shell", "pm", "disable-user", "--user", "0", packageName])

        if result.output.contains("disabled") {
            return
        }

        if result.output.contains("Error") || result.output.contains("Exception") {
            throw ADBError.appActionFailed("Disable", result.output)
        }

        if !result.isSuccess {
            throw ADBError.appActionFailed("Disable", result.combinedOutput)
        }
    }

    func enableApp(packageName: String, deviceId: String) async throws {
        try validatePackageName(packageName)
        let result = try await adb(deviceId: deviceId, ["shell", "pm", "enable", packageName])

        if result.output.contains("enabled") {
            return
        }

        if result.output.contains("Error") || result.output.contains("Exception") {
            throw ADBError.appActionFailed("Enable", result.output)
        }

        if !result.isSuccess {
            throw ADBError.appActionFailed("Enable", result.combinedOutput)
        }
    }

    func openAppSettings(packageName: String, deviceId: String) async throws {
        try validatePackageName(packageName)
        let result = try await adb(deviceId: deviceId, [
            "shell", "am", "start",
            "-a", "android.settings.APPLICATION_DETAILS_SETTINGS",
            "-d", "package:\(packageName)"
        ])

        if !result.isSuccess {
            throw ADBError.appActionFailed("Open Settings", result.combinedOutput)
        }
    }
}
