import Foundation

struct DeviceHistory: Codable, Identifiable {
    let persistentSerial: String
    var customName: String?
    var lastKnownIP: String?
    var lastKnownPort: Int?
    var lastSeen: Date
    var model: String?
    var brand: String?

    var id: String { persistentSerial }

    init(
        persistentSerial: String,
        customName: String? = nil,
        lastKnownIP: String? = nil,
        lastKnownPort: Int? = nil,
        lastSeen: Date = Date(),
        model: String? = nil,
        brand: String? = nil
    ) {
        self.persistentSerial = persistentSerial
        self.customName = customName
        self.lastKnownIP = lastKnownIP
        self.lastKnownPort = lastKnownPort
        self.lastSeen = lastSeen
        self.model = model
        self.brand = brand
    }

    var wifiAddress: String? {
        guard let ip = lastKnownIP, let port = lastKnownPort else { return nil }
        return "\(ip):\(port)"
    }
}
