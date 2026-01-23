import Foundation

enum DeviceState: String, Codable, Equatable, Hashable {
    case device = "device"
    case unauthorized = "unauthorized"
    case offline = "offline"
    case connecting = "connecting"
    case unknown = "unknown"

    var isConnected: Bool {
        self == .device
    }

    var displayName: String {
        switch self {
        case .device: return "Connected"
        case .unauthorized: return "Unauthorized"
        case .offline: return "Offline"
        case .connecting: return "Connecting..."
        case .unknown: return "Unknown"
        }
    }
}

struct Device: Identifiable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let adbId: String
    var additionalAdbIds: [String] = []
    var persistentSerial: String?
    var connection: DeviceConnection
    var additionalConnections: [DeviceConnection] = []
    var state: DeviceState
    var model: String?
    var brand: String?
    var androidVersion: String?
    var sdkVersion: String?
    var product: String?
    var customName: String?

    var id: String {
        persistentSerial ?? adbId
    }

    var displayName: String {
        customName ?? model ?? adbId
    }

    var allConnections: [DeviceConnection] {
        [connection] + additionalConnections
    }

    var hasMultipleConnections: Bool {
        !additionalConnections.isEmpty
    }

    var allAdbIds: [String] {
        [adbId] + additionalAdbIds
    }

    /// Prefers USB > TCP/IP > Wireless Debug
    var bestAdbId: String {
        if connection.type == .usb {
            return adbId
        }

        if connection.type == .wifi && connection.ipAddress != nil {
            return adbId
        }

        if let usbIndex = additionalConnections.firstIndex(where: { $0.type == .usb }),
           additionalAdbIds.indices.contains(usbIndex) {
            return additionalAdbIds[usbIndex]
        }

        if let tcpIndex = additionalConnections.firstIndex(where: { $0.type == .wifi && $0.ipAddress != nil }),
           additionalAdbIds.indices.contains(tcpIndex) {
            return additionalAdbIds[tcpIndex]
        }

        return adbId
    }

    var fullDescription: String {
        var parts: [String] = []
        if let brand = brand {
            parts.append(brand)
        }
        if let model = model {
            parts.append(model)
        }
        if parts.isEmpty {
            return adbId
        }
        return parts.joined(separator: " ")
    }

    init(
        adbId: String,
        persistentSerial: String? = nil,
        connection: DeviceConnection,
        state: DeviceState,
        model: String? = nil,
        brand: String? = nil,
        androidVersion: String? = nil,
        sdkVersion: String? = nil,
        product: String? = nil,
        customName: String? = nil
    ) {
        self.adbId = adbId
        self.persistentSerial = persistentSerial
        self.connection = connection
        self.state = state
        self.model = model
        self.brand = brand
        self.androidVersion = androidVersion
        self.sdkVersion = sdkVersion
        self.product = product
        self.customName = customName
    }
}

extension Device {
    static func fromADBLine(adbId: String, state: DeviceState, connection: DeviceConnection, model: String? = nil, product: String? = nil) -> Device {
        Device(
            adbId: adbId,
            connection: connection,
            state: state,
            model: model,
            product: product
        )
    }
}
