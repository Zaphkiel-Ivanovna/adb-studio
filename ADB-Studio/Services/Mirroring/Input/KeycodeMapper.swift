import AppKit
import Carbon.HIToolbox
import Foundation

struct KeycodeMapper {
    static func androidKeycode(for nsKeyCode: UInt16) -> Int32? {
        return map[nsKeyCode]
    }

    static func metaState(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var state: UInt32 = 0
        if flags.contains(.shift) { state |= META_SHIFT_ON }
        if flags.contains(.option) { state |= META_ALT_ON }
        if flags.contains(.control) { state |= META_CTRL_ON }
        if flags.contains(.command) { state |= META_META_ON }
        if flags.contains(.capsLock) { state |= META_CAPS_LOCK_ON }
        if flags.contains(.function) { state |= META_FUNCTION_ON }
        return state
    }

    static let META_SHIFT_ON: UInt32 = 0x1
    static let META_ALT_ON: UInt32 = 0x2
    static let META_SYM_ON: UInt32 = 0x4
    static let META_FUNCTION_ON: UInt32 = 0x8
    static let META_CTRL_ON: UInt32 = 0x1000
    static let META_META_ON: UInt32 = 0x10000
    static let META_CAPS_LOCK_ON: UInt32 = 0x100000

    private static let map: [UInt16: Int32] = [
        UInt16(kVK_ANSI_A): 29,
        UInt16(kVK_ANSI_B): 30,
        UInt16(kVK_ANSI_C): 31,
        UInt16(kVK_ANSI_D): 32,
        UInt16(kVK_ANSI_E): 33,
        UInt16(kVK_ANSI_F): 34,
        UInt16(kVK_ANSI_G): 35,
        UInt16(kVK_ANSI_H): 36,
        UInt16(kVK_ANSI_I): 37,
        UInt16(kVK_ANSI_J): 38,
        UInt16(kVK_ANSI_K): 39,
        UInt16(kVK_ANSI_L): 40,
        UInt16(kVK_ANSI_M): 41,
        UInt16(kVK_ANSI_N): 42,
        UInt16(kVK_ANSI_O): 43,
        UInt16(kVK_ANSI_P): 44,
        UInt16(kVK_ANSI_Q): 45,
        UInt16(kVK_ANSI_R): 46,
        UInt16(kVK_ANSI_S): 47,
        UInt16(kVK_ANSI_T): 48,
        UInt16(kVK_ANSI_U): 49,
        UInt16(kVK_ANSI_V): 50,
        UInt16(kVK_ANSI_W): 51,
        UInt16(kVK_ANSI_X): 52,
        UInt16(kVK_ANSI_Y): 53,
        UInt16(kVK_ANSI_Z): 54,

        UInt16(kVK_ANSI_0): 7,
        UInt16(kVK_ANSI_1): 8,
        UInt16(kVK_ANSI_2): 9,
        UInt16(kVK_ANSI_3): 10,
        UInt16(kVK_ANSI_4): 11,
        UInt16(kVK_ANSI_5): 12,
        UInt16(kVK_ANSI_6): 13,
        UInt16(kVK_ANSI_7): 14,
        UInt16(kVK_ANSI_8): 15,
        UInt16(kVK_ANSI_9): 16,

        UInt16(kVK_Space): 62,
        UInt16(kVK_Return): 66,
        UInt16(kVK_ANSI_KeypadEnter): 66,
        UInt16(kVK_Escape): 111,
        UInt16(kVK_Tab): 61,
        UInt16(kVK_Delete): 67,
        UInt16(kVK_ForwardDelete): 112,

        UInt16(kVK_LeftArrow): 21,
        UInt16(kVK_RightArrow): 22,
        UInt16(kVK_UpArrow): 19,
        UInt16(kVK_DownArrow): 20,

        UInt16(kVK_Home): 122,
        UInt16(kVK_End): 123,
        UInt16(kVK_PageUp): 92,
        UInt16(kVK_PageDown): 93,

        UInt16(kVK_F1): 131,
        UInt16(kVK_F2): 132,
        UInt16(kVK_F3): 133,
        UInt16(kVK_F4): 134,
        UInt16(kVK_F5): 135,
        UInt16(kVK_F6): 136,
        UInt16(kVK_F7): 137,
        UInt16(kVK_F8): 138,
        UInt16(kVK_F9): 139,
        UInt16(kVK_F10): 140,
        UInt16(kVK_F11): 141,
        UInt16(kVK_F12): 142,

        UInt16(kVK_ANSI_Minus): 69,
        UInt16(kVK_ANSI_Equal): 70,
        UInt16(kVK_ANSI_LeftBracket): 71,
        UInt16(kVK_ANSI_RightBracket): 72,
        UInt16(kVK_ANSI_Backslash): 73,
        UInt16(kVK_ANSI_Semicolon): 74,
        UInt16(kVK_ANSI_Quote): 75,
        UInt16(kVK_ANSI_Comma): 55,
        UInt16(kVK_ANSI_Period): 56,
        UInt16(kVK_ANSI_Slash): 76,
        UInt16(kVK_ANSI_Grave): 68,
    ]
}
