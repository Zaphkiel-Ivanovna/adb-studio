import Foundation

struct ADBOutputParser {

    static func parseDevicesList(_ output: String) -> [Device] {
        var devices: [Device] = []

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.starts(with: "List of devices") || trimmed.starts(with: "*") {
                continue
            }
            if let device = parseDeviceLine(trimmed) {
                devices.append(device)
            }
        }

        return devices
    }

    static func parseDeviceLine(_ line: String) -> Device? {
        let components = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard components.count >= 2 else { return nil }

        let adbId = components[0]
        let state = DeviceState(rawValue: components[1]) ?? .unknown

        var model: String?
        var product: String?
        var transportId: String?

        for component in components.dropFirst(2) {
            if component.starts(with: "model:") {
                model = String(component.dropFirst(6)).replacingOccurrences(of: "_", with: " ")
            } else if component.starts(with: "product:") {
                product = String(component.dropFirst(8))
            } else if component.starts(with: "transport_id:") {
                transportId = String(component.dropFirst(13))
            }
        }

        let connection = parseConnectionType(adbId: adbId, transportId: transportId)

        return Device.fromADBLine(
            adbId: adbId,
            state: state,
            connection: connection,
            model: model,
            product: product
        )
    }

    static func parseConnectionType(adbId: String, transportId: String?) -> DeviceConnection {
        // adb-SERIAL-*._adb-tls-connect._tcp
        if adbId.contains("._adb-tls-connect._tcp") || (adbId.starts(with: "adb-") && adbId.contains("._tcp")) {
            return .wirelessDebug(transportId: transportId)
        }

        // IP:PORT
        if let colonIndex = adbId.lastIndex(of: ":") {
            let potentialIP = String(adbId[..<colonIndex])
            let potentialPort = String(adbId[adbId.index(after: colonIndex)...])

            if isIPAddress(potentialIP), let port = Int(potentialPort) {
                return .wifi(ipAddress: potentialIP, port: port, transportId: transportId)
            }
        }

        return .usb(transportId: transportId)
    }

    private static func isIPAddress(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let num = Int(part) else { return false }
            return num >= 0 && num <= 255
        }
    }

    static func parseReverseList(_ output: String, deviceId: String) -> [PortForward] {
        output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { PortForward.fromReverseListLine($0, deviceId: deviceId) }
    }

    static func parseForwardList(_ output: String, deviceId: String) -> [PortForward] {
        output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { PortForward.fromForwardListLine($0, deviceId: deviceId) }
    }

    // MARK: - Package Parsing

    static func parsePackageList(_ output: String) -> [String] {
        output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("package:") }
            .map { String($0.dropFirst(8)) }
    }

    static func parsePackageInfo(_ output: String, packageName: String) -> InstalledApp {
        let displayName: String? = nil
        var versionName: String?
        var versionCode: Int?
        var installTime: Date?
        var updateTime: Date?
        var isSystemApp = false
        var isEnabled = true

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("versionName=") {
                let value = String(trimmed.dropFirst(12))
                versionName = value.count <= 100 ? value : String(value.prefix(100))
            } else if trimmed.hasPrefix("versionCode=") {
                let codeStr = String(trimmed.dropFirst(12))
                if let spaceIndex = codeStr.firstIndex(of: " ") {
                    versionCode = Int(codeStr[..<spaceIndex])
                } else {
                    versionCode = Int(codeStr)
                }
            } else if trimmed.hasPrefix("firstInstallTime=") {
                let dateStr = String(trimmed.dropFirst(17))
                installTime = parseAndroidDate(dateStr)
            } else if trimmed.hasPrefix("lastUpdateTime=") {
                let dateStr = String(trimmed.dropFirst(15))
                updateTime = parseAndroidDate(dateStr)
            } else if trimmed.contains("pkgFlags=") && trimmed.contains("SYSTEM") {
                isSystemApp = true
            } else if trimmed.hasPrefix("enabled=") {
                let state = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                // enabled=0 means disabled, enabled=1 or enabled=2 means enabled
                if state == "0" || state.lowercased() == "false" {
                    isEnabled = false
                }
            } else if trimmed.contains("Package [") && trimmed.contains("] (") {
                // Try to extract display name from the package line if available
            }
        }

        // Check for disabled state in packageFlags
        if output.contains("packageFlags=[ HIDDEN ]") || output.contains("DISABLED") {
            isEnabled = false
        }

        // Also check for enabled state explicitly
        if output.contains("enabledState=COMPONENT_ENABLED_STATE_DISABLED") {
            isEnabled = false
        }

        return InstalledApp(
            packageName: packageName,
            displayName: displayName,
            versionName: versionName,
            versionCode: versionCode,
            installTime: installTime,
            updateTime: updateTime,
            isSystemApp: isSystemApp,
            isEnabled: isEnabled
        )
    }

    private static func parseAndroidDate(_ dateStr: String) -> Date? {
        // Format: "2024-01-15 10:30:45"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateStr)
    }
}
