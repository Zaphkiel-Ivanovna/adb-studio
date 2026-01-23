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
}
