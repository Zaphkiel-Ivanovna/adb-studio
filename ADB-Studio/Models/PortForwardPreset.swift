import Foundation

struct PortForwardPreset: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String?
    var localPort: Int
    var remotePort: Int
    var autoApply: Bool

    init(
        id: UUID = UUID(),
        name: String? = nil,
        localPort: Int,
        remotePort: Int,
        autoApply: Bool = false
    ) {
        self.id = id
        self.name = name?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        self.localPort = localPort
        self.remotePort = remotePort
        self.autoApply = autoApply
    }

    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return portsDescription
    }

    var portsDescription: String {
        "Device:\(localPort) → Local:\(remotePort)"
    }

    var commandDescription: String {
        "adb reverse tcp:\(localPort) tcp:\(remotePort)"
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
