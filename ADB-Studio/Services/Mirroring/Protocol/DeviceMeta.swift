import Foundation

public enum VideoCodec: UInt32 {
    case h264 = 0x68323634
    case h265 = 0x68323635
    case av1  = 0x00617631
}

public enum DeviceMetaError: Error {
    case invalidDeviceNameSize
    case invalidCodecHeaderSize
    case unknownCodec(UInt32)
}

public struct DeviceMeta {
    public static let deviceNameSize = 64
    public static let codecHeaderSize = 12
    public static let totalSize = deviceNameSize + codecHeaderSize

    public let name: String
    public let codecID: UInt32
    public let codec: VideoCodec
    public let width: Int
    public let height: Int

    public init(name: String, codecID: UInt32, codec: VideoCodec, width: Int, height: Int) {
        self.name = name
        self.codecID = codecID
        self.codec = codec
        self.width = width
        self.height = height
    }

    public init(deviceName: Data, codecHeader: Data) throws {
        guard deviceName.count == DeviceMeta.deviceNameSize else {
            throw DeviceMetaError.invalidDeviceNameSize
        }
        guard codecHeader.count == DeviceMeta.codecHeaderSize else {
            throw DeviceMetaError.invalidCodecHeaderSize
        }

        let nullIndex = deviceName.firstIndex(of: 0) ?? deviceName.endIndex
        let nameBytes = deviceName.prefix(upTo: nullIndex)
        self.name = String(data: Data(nameBytes), encoding: .utf8) ?? ""

        let codecID = codecHeader.readUInt32BE(at: 0)
        let width = codecHeader.readUInt32BE(at: 4)
        let height = codecHeader.readUInt32BE(at: 8)

        guard let codec = VideoCodec(rawValue: codecID) else {
            throw DeviceMetaError.unknownCodec(codecID)
        }

        self.codecID = codecID
        self.codec = codec
        self.width = Int(width)
        self.height = Int(height)
    }

    public init(from data: Data) throws {
        guard data.count == DeviceMeta.totalSize else {
            throw DeviceMetaError.invalidDeviceNameSize
        }
        let deviceName = data.subdata(in: data.startIndex..<(data.startIndex + DeviceMeta.deviceNameSize))
        let codecHeader = data.subdata(in: (data.startIndex + DeviceMeta.deviceNameSize)..<(data.startIndex + DeviceMeta.totalSize))
        try self.init(deviceName: deviceName, codecHeader: codecHeader)
    }
}

extension Data {
    func readUInt32BE(at offset: Int) -> UInt32 {
        let base = self.startIndex + offset
        let b0 = UInt32(self[base])
        let b1 = UInt32(self[base + 1])
        let b2 = UInt32(self[base + 2])
        let b3 = UInt32(self[base + 3])
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    func readUInt64BE(at offset: Int) -> UInt64 {
        let base = self.startIndex + offset
        var value: UInt64 = 0
        for i in 0..<8 {
            value = (value << 8) | UInt64(self[base + i])
        }
        return value
    }
}
