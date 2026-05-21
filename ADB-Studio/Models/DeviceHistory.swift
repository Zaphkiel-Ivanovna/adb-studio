import Foundation

struct DeviceHistory: Codable, Identifiable {
    let persistentSerial: String
    var customName: String?
    var lastKnownIP: String?
    var lastKnownPort: Int?
    var lastSeen: Date
    var model: String?
    var brand: String?
    var portForwardPresets: [PortForwardPreset]

    var id: String { persistentSerial }

    init(
        persistentSerial: String,
        customName: String? = nil,
        lastKnownIP: String? = nil,
        lastKnownPort: Int? = nil,
        lastSeen: Date = Date(),
        model: String? = nil,
        brand: String? = nil,
        portForwardPresets: [PortForwardPreset] = []
    ) {
        self.persistentSerial = persistentSerial
        self.customName = customName
        self.lastKnownIP = lastKnownIP
        self.lastKnownPort = lastKnownPort
        self.lastSeen = lastSeen
        self.model = model
        self.brand = brand
        self.portForwardPresets = portForwardPresets
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.persistentSerial = try c.decode(String.self, forKey: .persistentSerial)
        self.customName = try c.decodeIfPresent(String.self, forKey: .customName)
        self.lastKnownIP = try c.decodeIfPresent(String.self, forKey: .lastKnownIP)
        self.lastKnownPort = try c.decodeIfPresent(Int.self, forKey: .lastKnownPort)
        self.lastSeen = try c.decodeIfPresent(Date.self, forKey: .lastSeen) ?? Date()
        self.model = try c.decodeIfPresent(String.self, forKey: .model)
        self.brand = try c.decodeIfPresent(String.self, forKey: .brand)
        self.portForwardPresets = try c.decodeIfPresent([PortForwardPreset].self, forKey: .portForwardPresets) ?? []
    }

    var wifiAddress: String? {
        guard let ip = lastKnownIP, let port = lastKnownPort else { return nil }
        return "\(ip):\(port)"
    }

    var displayLabel: String {
        if let customName = customName, !customName.isEmpty {
            return customName
        }
        if let brand = brand, let model = model {
            return "\(brand) \(model)"
        }
        return model ?? brand ?? persistentSerial
    }
}
