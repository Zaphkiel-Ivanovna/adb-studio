import Foundation

enum ScrcpyVideoCodec: String {
    case h264
    case h265
    case av1
}

enum ScrcpyLogLevel: String {
    case verbose
    case debug
    case info
    case warn
    case error
}

struct ServerParameters {
    static let scrcpyServerVersion = "3.3.4"

    var logLevel: ScrcpyLogLevel = .info
    var videoCodec: ScrcpyVideoCodec = .h264
    var videoBitRate: Int = 8_000_000
    var maxSize: Int = 0
    var maxFps: Int = 60
    var tunnelForward: Bool = false
    var stayAwake: Bool = false
    var showTouches: Bool = false
    var audio: Bool = false
    var control: Bool = true
    var sendDeviceMeta: Bool = true
    var sendFrameMeta: Bool = true
    var sendDummyByte: Bool = false
    var clipboardAutosync: Bool = false
    var cleanup: Bool = true
    var powerOn: Bool = true

    init() {}

    /// `scid` is owned by the caller (MirroringManager) so that the transport
    /// layer and the server agree on the abstract socket name `scrcpy_<scid>`.
    func toArguments(scid: Int32) -> [String] {
        var args: [String] = []
        args.append("scid=\(ServerParameters.formatScid(scid))")
        args.append("log_level=\(logLevel.rawValue)")
        args.append("video_codec=\(videoCodec.rawValue)")
        args.append("video_bit_rate=\(videoBitRate)")
        if maxSize > 0 { args.append("max_size=\(maxSize)") }
        if maxFps > 0 { args.append("max_fps=\(maxFps)") }
        args.append("tunnel_forward=\(tunnelForward ? "true" : "false")")
        args.append("stay_awake=\(stayAwake ? "true" : "false")")
        args.append("show_touches=\(showTouches ? "true" : "false")")
        args.append("audio=\(audio ? "true" : "false")")
        args.append("control=\(control ? "true" : "false")")
        args.append("send_device_meta=\(sendDeviceMeta ? "true" : "false")")
        args.append("send_frame_meta=\(sendFrameMeta ? "true" : "false")")
        args.append("send_dummy_byte=\(sendDummyByte ? "true" : "false")")
        args.append("clipboard_autosync=\(clipboardAutosync ? "true" : "false")")
        args.append("cleanup=\(cleanup ? "true" : "false")")
        args.append("power_on=\(powerOn ? "true" : "false")")
        return args
    }

    /// Matches scrcpy server's 31-bit non-negative SCID range.
    static func generateScid() -> Int32 {
        return Int32.random(in: 0...0x7FFF_FFFF)
    }

    static func formatScid(_ scid: Int32) -> String {
        return String(format: "%08x", UInt32(bitPattern: scid))
    }

    /// Must mirror `DesktopConnection.getSocketName` in scrcpy v3.3.4:
    /// `"scrcpy_" + String.format("%08x", scid)`.
    static func socketName(for scid: Int32) -> String {
        return "scrcpy_\(formatScid(scid))"
    }
}
