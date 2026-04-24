import Foundation
import Network

public enum VideoPacketError: Error {
    case connectionClosed
    case transport(Error)
    case invalidHeader
    case oversizedPayload(Int)
}

public struct VideoPacket {
    public static let headerSize = 12
    public static let flagConfig: UInt64   = 0x8000_0000_0000_0000
    public static let flagKeyFrame: UInt64 = 0x4000_0000_0000_0000
    public static let ptsMask: UInt64      = 0x3FFF_FFFF_FFFF_FFFF
    public static let ptsNone: Int64       = -1
    public static let maxPayloadBytes      = 16 * 1024 * 1024

    public let pts: Int64
    public let isConfig: Bool
    public let isKeyFrame: Bool
    public let data: Data

    public init(pts: Int64, isConfig: Bool, isKeyFrame: Bool, data: Data) {
        self.pts = pts
        self.isConfig = isConfig
        self.isKeyFrame = isKeyFrame
        self.data = data
    }

    public static func read(from connection: NWConnection) async throws -> VideoPacket {
        let header = try await readExactly(connection, VideoPacket.headerSize)
        let raw = header.readUInt64BE(at: 0)
        let size = Int(header.readUInt32BE(at: 8))

        guard size >= 0, size <= VideoPacket.maxPayloadBytes else {
            throw VideoPacketError.oversizedPayload(size)
        }

        let isConfig = (raw & VideoPacket.flagConfig) != 0
        let isKeyFrame = (raw & VideoPacket.flagKeyFrame) != 0

        let ptsRaw = raw & VideoPacket.ptsMask
        let pts: Int64
        if ptsRaw == VideoPacket.ptsMask {
            pts = VideoPacket.ptsNone
        } else {
            pts = Int64(ptsRaw)
        }

        let payload = size > 0 ? try await readExactly(connection, size) : Data()
        return VideoPacket(pts: pts, isConfig: isConfig, isKeyFrame: isKeyFrame, data: payload)
    }
}

func readExactly(_ connection: NWConnection, _ count: Int) async throws -> Data {
    guard count > 0 else { return Data() }
    return try await withCheckedThrowingContinuation { continuation in
        connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, isComplete, error in
            if let error = error {
                continuation.resume(throwing: VideoPacketError.transport(error))
                return
            }
            if let data = data, data.count == count {
                continuation.resume(returning: data)
                return
            }
            if isComplete {
                continuation.resume(throwing: VideoPacketError.connectionClosed)
                return
            }
            continuation.resume(throwing: VideoPacketError.invalidHeader)
        }
    }
}
