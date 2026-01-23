import Foundation

enum ConnectionType: String, Codable, Equatable, Hashable {
    case usb = "usb"
    case wifi = "wifi"
    case wirelessDebug = "wirelessDebug"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .usb: return "USB"
        case .wifi: return "TCP/IP"
        case .wirelessDebug: return "Wireless Debug"
        case .unknown: return "Unknown"
        }
    }
}

struct DeviceConnection: Equatable, Codable, Hashable {
    let type: ConnectionType
    let transportId: String?
    let ipAddress: String?
    let port: Int?

    var displayString: String {
        switch type {
        case .usb:
            return "USB"
        case .wifi:
            if let ip = ipAddress, let port = port {
                return "\(ip):\(port)"
            }
            return "TCP/IP"
        case .wirelessDebug:
            if let ip = ipAddress, let port = port {
                return "Wireless Debug (\(ip):\(port))"
            }
            return "Wireless Debug"
        case .unknown:
            return "Unknown"
        }
    }

    var isWiFiBased: Bool {
        type == .wifi || type == .wirelessDebug
    }

    static func usb(transportId: String? = nil) -> DeviceConnection {
        DeviceConnection(type: .usb, transportId: transportId, ipAddress: nil, port: nil)
    }

    static func wifi(ipAddress: String?, port: Int?, transportId: String? = nil) -> DeviceConnection {
        DeviceConnection(type: .wifi, transportId: transportId, ipAddress: ipAddress, port: port)
    }

    static func wirelessDebug(transportId: String? = nil) -> DeviceConnection {
        DeviceConnection(type: .wirelessDebug, transportId: transportId, ipAddress: nil, port: nil)
    }
}
