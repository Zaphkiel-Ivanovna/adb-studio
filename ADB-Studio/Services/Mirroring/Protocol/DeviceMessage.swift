import Foundation
import Network

enum DeviceMessageType: UInt8 {
    case clipboard = 0
    case uhidOutput = 1
    case uhidReport = 2
    case ackClipboard = 3
}

enum DeviceMessage {
    case clipboard(String)
    case ackClipboard(sequence: UInt64)
    case unsupported

    static let maxClipboardBytes = 262_144

    static func read(from connection: NWConnection) async throws -> DeviceMessage {
        let typeByte = try await readExactly(connection, 1)
        guard let rawType = typeByte.first,
              let type = DeviceMessageType(rawValue: rawType) else {
            return .unsupported
        }

        switch type {
        case .clipboard:
            let lengthBytes = try await readExactly(connection, 4)
            let length = Int(lengthBytes.readUInt32BE(at: 0))
            guard length >= 0, length <= Self.maxClipboardBytes else { return .unsupported }
            guard length > 0 else { return .clipboard("") }
            let textBytes = try await readExactly(connection, length)
            let text = String(data: textBytes, encoding: .utf8) ?? ""
            return .clipboard(text)

        case .ackClipboard:
            let seqBytes = try await readExactly(connection, 8)
            let seq = seqBytes.readUInt64BE(at: 0)
            return .ackClipboard(sequence: seq)

        case .uhidOutput, .uhidReport:
            return .unsupported
        }
    }
}
