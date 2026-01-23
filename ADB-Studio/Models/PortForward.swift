import Foundation

enum PortForwardDirection: String, Codable {
    case forward = "forward"
    case reverse = "reverse"
}

struct PortForward: Identifiable, Equatable, Codable {
    let id: UUID
    let deviceId: String
    let direction: PortForwardDirection
    let localPort: Int
    let remotePort: Int
    let localSpec: String
    let remoteSpec: String

    var displayString: String {
        switch direction {
        case .forward:
            return "Local:\(localPort) → Device:\(remotePort)"
        case .reverse:
            return "Device:\(localPort) → Local:\(remotePort)"
        }
    }

    init(
        id: UUID = UUID(),
        deviceId: String,
        direction: PortForwardDirection,
        localPort: Int,
        remotePort: Int
    ) {
        self.id = id
        self.deviceId = deviceId
        self.direction = direction
        self.localPort = localPort
        self.remotePort = remotePort
        self.localSpec = "tcp:\(localPort)"
        self.remoteSpec = "tcp:\(remotePort)"
    }

    static func fromReverseListLine(_ line: String, deviceId: String) -> PortForward? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: " ").map(String.init)

        var tcpParts: [String] = []
        for part in parts {
            if part.hasPrefix("tcp:") {
                tcpParts.append(part)
            }
        }

        guard tcpParts.count >= 2,
              let localPort = parsePort(tcpParts[0]),
              let remotePort = parsePort(tcpParts[1]) else {
            return nil
        }

        return PortForward(
            deviceId: deviceId,
            direction: .reverse,
            localPort: localPort,
            remotePort: remotePort
        )
    }

    static func fromForwardListLine(_ line: String, deviceId: String) -> PortForward? {
        let parts = line.split(separator: " ")
        guard parts.count >= 3,
              let localPort = parsePort(String(parts[1])),
              let remotePort = parsePort(String(parts[2])) else {
            return nil
        }

        return PortForward(
            deviceId: deviceId,
            direction: .forward,
            localPort: localPort,
            remotePort: remotePort
        )
    }

    private static func parsePort(_ spec: String) -> Int? {
        guard spec.hasPrefix("tcp:") else { return nil }
        return Int(spec.replacingOccurrences(of: "tcp:", with: ""))
    }
}
