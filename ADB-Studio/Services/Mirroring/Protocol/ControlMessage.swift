import Foundation

public enum ControlMessageType: UInt8 {
    case injectKeycode = 0
    case injectText = 1
    case injectTouchEvent = 2
    case injectScrollEvent = 3
    case backOrScreenOn = 4
    case expandNotificationPanel = 5
    case expandSettingsPanel = 6
    case collapsePanels = 7
    case getClipboard = 8
    case setClipboard = 9
    case setDisplayPower = 10
    case rotateDevice = 11
    case uhidCreate = 12
    case uhidInput = 13
    case uhidDestroy = 14
    case openHardKeyboardSettings = 15
    case startApp = 16
    case resetVideo = 17
}

public enum KeyAction: UInt8 {
    case down = 0
    case up = 1
}

public enum MotionAction: UInt8 {
    case down = 0
    case up = 1
    case move = 2
    case cancel = 3
    case outside = 4
    case pointerDown = 5
    case pointerUp = 6
    case hoverMove = 7
    case scroll = 8
    case hoverEnter = 9
    case hoverExit = 10
    case buttonPress = 11
    case buttonRelease = 12
}

public enum CopyKey: UInt8 {
    case none = 0
    case copy = 1
    case cut = 2
}

public enum ControlMessage {
    case injectKeycode(action: KeyAction, keycode: Int32, repeatCount: UInt32, metaState: UInt32)
    case injectText(String)
    case injectTouch(action: MotionAction,
                     pointerId: UInt64,
                     x: Int32,
                     y: Int32,
                     screenWidth: UInt16,
                     screenHeight: UInt16,
                     pressure: Float,
                     actionButton: UInt32,
                     buttons: UInt32)
    case injectScroll(x: Int32,
                      y: Int32,
                      screenWidth: UInt16,
                      screenHeight: UInt16,
                      hScroll: Float,
                      vScroll: Float,
                      buttons: UInt32)
    case backOrScreenOn(action: KeyAction)
    case expandNotificationPanel
    case expandSettingsPanel
    case collapsePanels
    case getClipboard(copyKey: CopyKey)
    case setClipboard(sequence: UInt64, paste: Bool, text: String)
    case setDisplayPower(on: Bool)
    case rotateDevice
    case openHardKeyboardSettings
    case resetVideo

    public var type: ControlMessageType {
        switch self {
        case .injectKeycode: return .injectKeycode
        case .injectText: return .injectText
        case .injectTouch: return .injectTouchEvent
        case .injectScroll: return .injectScrollEvent
        case .backOrScreenOn: return .backOrScreenOn
        case .expandNotificationPanel: return .expandNotificationPanel
        case .expandSettingsPanel: return .expandSettingsPanel
        case .collapsePanels: return .collapsePanels
        case .getClipboard: return .getClipboard
        case .setClipboard: return .setClipboard
        case .setDisplayPower: return .setDisplayPower
        case .rotateDevice: return .rotateDevice
        case .openHardKeyboardSettings: return .openHardKeyboardSettings
        case .resetVideo: return .resetVideo
        }
    }

    public static let injectTextMaxLength = 300
    public static let clipboardTextMaxLength = (1 << 18) - 14

    public func encode() -> Data {
        var buffer = Data()
        buffer.append(type.rawValue)

        switch self {
        case let .injectKeycode(action, keycode, repeatCount, metaState):
            buffer.append(action.rawValue)
            buffer.appendUInt32BE(UInt32(bitPattern: keycode))
            buffer.appendUInt32BE(repeatCount)
            buffer.appendUInt32BE(metaState)

        case let .injectText(text):
            let truncated = text.utf8TruncatedToByteLimit(ControlMessage.injectTextMaxLength)
            let bytes = Data(truncated.utf8)
            buffer.appendUInt32BE(UInt32(bytes.count))
            buffer.append(bytes)

        case let .injectTouch(action, pointerId, x, y, screenWidth, screenHeight, pressure, actionButton, buttons):
            buffer.append(action.rawValue)
            buffer.appendUInt64BE(pointerId)
            buffer.appendUInt32BE(UInt32(bitPattern: x))
            buffer.appendUInt32BE(UInt32(bitPattern: y))
            buffer.appendUInt16BE(screenWidth)
            buffer.appendUInt16BE(screenHeight)
            buffer.appendUInt16BE(ControlMessage.floatToU16FixedPoint(pressure))
            buffer.appendUInt32BE(actionButton)
            buffer.appendUInt32BE(buttons)

        case let .injectScroll(x, y, screenWidth, screenHeight, hScroll, vScroll, buttons):
            buffer.appendUInt32BE(UInt32(bitPattern: x))
            buffer.appendUInt32BE(UInt32(bitPattern: y))
            buffer.appendUInt16BE(screenWidth)
            buffer.appendUInt16BE(screenHeight)
            buffer.appendInt16BE(ControlMessage.floatToI16FixedPoint(hScroll))
            buffer.appendInt16BE(ControlMessage.floatToI16FixedPoint(vScroll))
            buffer.appendUInt32BE(buttons)

        case let .backOrScreenOn(action):
            buffer.append(action.rawValue)

        case .expandNotificationPanel,
             .expandSettingsPanel,
             .collapsePanels,
             .rotateDevice,
             .openHardKeyboardSettings,
             .resetVideo:
            break

        case let .getClipboard(copyKey):
            buffer.append(copyKey.rawValue)

        case let .setClipboard(sequence, paste, text):
            buffer.appendUInt64BE(sequence)
            buffer.append(paste ? 1 : 0)
            let truncated = text.utf8TruncatedToByteLimit(ControlMessage.clipboardTextMaxLength)
            let bytes = Data(truncated.utf8)
            buffer.appendUInt32BE(UInt32(bytes.count))
            buffer.append(bytes)

        case let .setDisplayPower(on):
            buffer.append(on ? 1 : 0)
        }

        return buffer
    }

    static func floatToU16FixedPoint(_ f: Float) -> UInt16 {
        let clamped = max(0, min(1, f))
        let u = UInt32(clamped * Float(1 << 16))
        return u >= 0xFFFF ? 0xFFFF : UInt16(u)
    }

    static func floatToI16FixedPoint(_ f: Float) -> Int16 {
        let clamped = max(-1, min(1, f))
        let i = Int32(clamped * Float(1 << 15))
        if i >= 0x7FFF { return 0x7FFF }
        if i <= -0x8000 { return -0x8000 }
        return Int16(i)
    }
}

extension Data {
    mutating func appendUInt16BE(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }

    mutating func appendInt16BE(_ value: Int16) {
        appendUInt16BE(UInt16(bitPattern: value))
    }

    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }

    mutating func appendUInt64BE(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            append(UInt8((value >> shift) & 0xFF))
        }
    }
}

extension String {
    func utf8TruncatedToByteLimit(_ limit: Int) -> String {
        let utf8 = Data(self.utf8)
        if utf8.count <= limit { return self }
        var end = limit
        while end > 0 {
            let byte = utf8[end]
            if (byte & 0xC0) != 0x80 { break }
            end -= 1
        }
        let slice = utf8.prefix(end)
        return String(data: Data(slice), encoding: .utf8) ?? ""
    }
}
