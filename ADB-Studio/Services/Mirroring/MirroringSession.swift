import AppKit
import Foundation
import Combine
import CoreGraphics
import CoreMedia

@MainActor
final class MirroringSession: ObservableObject {
    enum State: Equatable {
        case idle
        case connecting
        case streaming
        case disconnected
        case error(MirroringError)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.connecting, .connecting), (.streaming, .streaming), (.disconnected, .disconnected):
                return true
            case (.error(let a), .error(let b)):
                return a.localizedDescription == b.localizedDescription
            default:
                return false
            }
        }
    }

    let adbId: String
    let deviceName: String
    let renderer: SampleBufferRenderer

    @Published private(set) var state: State = .idle
    @Published private(set) var fps: Double = 0
    @Published private(set) var bitrate: Int = 0
    @Published private(set) var resolution: CGSize?
    @Published private(set) var remoteDeviceName: String = ""
    @Published private(set) var codec: VideoCodec = .h264
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var lastScreenshotURL: URL?

    private let adbService: ADBService
    private let parameters: ServerParameters
    private let launcher: ServerLauncher
    private let scid: Int32
    private let transport: SessionTransport
    private let turnOffDisplayOnStart: Bool

    private var launchResult: ServerLaunchResult?
    private var decoder: H264Decoder?
    private var consumerTask: Task<Void, Never>?
    private var batteryTask: Task<Void, Never>?
    private var onFinished: ((MirroringSession) -> Void)?
    private var isStopping = false

    private var packetsInWindow: Int = 0
    private var bytesInWindow: Int = 0
    private var windowStart: Date = Date()

    init(
        adbId: String,
        deviceName: String,
        adbService: ADBService,
        parameters: ServerParameters = ServerParameters(),
        turnOffDisplayOnStart: Bool = false,
        onFinished: @escaping (MirroringSession) -> Void = { _ in }
    ) {
        self.adbId = adbId
        self.deviceName = deviceName
        self.adbService = adbService
        self.parameters = parameters
        self.turnOffDisplayOnStart = turnOffDisplayOnStart
        self.renderer = SampleBufferRenderer()
        self.launcher = ServerLauncher(adbService: adbService)
        self.onFinished = onFinished

        let scid = ServerParameters.generateScid()
        self.scid = scid
        self.transport = SessionTransport(config: SessionTransport.Config(
            deviceId: adbId,
            scid: scid,
            adbService: adbService
        ))
    }

    func start() async {
        guard case .idle = state else { return }
        state = .connecting

        do {
            let launch = try await launcher.launch(
                deviceId: adbId,
                parameters: parameters,
                scid: scid,
                onLog: { _ in }
            )
            self.launchResult = launch
        } catch let error as MirroringError {
            state = .error(error)
            await finish()
            return
        } catch {
            state = .error(.serverLaunchFailed(error.localizedDescription))
            await finish()
            return
        }

        let stream = await transport.run()
        windowStart = Date()

        consumerTask = Task { [weak self] in
            guard let self else { return }
            for await event in stream {
                if Task.isCancelled { break }
                await self.handle(event: event)
            }
            await self.onStreamEnded()
        }

        startBatteryPolling()
    }

    func send(control message: ControlMessage) async {
        do {
            try await transport.send(control: message)
        } catch {
            state = .error(.controlSocketClosed)
            await stop()
        }
    }

    func stop() async {
        guard !isStopping else { return }
        isStopping = true
        consumerTask?.cancel()
        consumerTask = nil
        batteryTask?.cancel()
        batteryTask = nil
        await transport.shutdown()
        if let launch = launchResult {
            await launcher.cleanup(result: launch, deviceId: adbId)
            launchResult = nil
        }
        decoder?.shutdown()
        decoder = nil
        renderer.flush()
        if case .streaming = state {
            state = .disconnected
        }
        await finish()
    }

    func markDeviceGone() {
        if case .streaming = state {
            state = .disconnected
        }
        Task { await self.stop() }
    }

    private func handle(event: SessionTransport.Event) async {
        switch event {
        case .ready(let meta):
            remoteDeviceName = meta.name
            codec = meta.codec
            resolution = CGSize(width: meta.width, height: meta.height)
            setupDecoder(width: meta.width, height: meta.height)
            state = .streaming
            if turnOffDisplayOnStart {
                Task { [weak self] in await self?.send(control: .setDisplayPower(on: false)) }
            }

        case .video(let packet):
            packetsInWindow += 1
            bytesInWindow += packet.data.count
            updateMetricsIfNeeded()

            if packet.isConfig {
                decoder?.feedConfig(packet.data)
            } else {
                decoder?.decode(naluData: packet.data, pts: packet.pts)
            }

        case .clipboard(let text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)

        case .disconnected:
            if case .streaming = state {
                state = .disconnected
            }

        case .error(let err):
            state = .error(err)
        }
    }

    func copyFromDevice() async {
        await send(control: .getClipboard(copyKey: .copy))
    }

    func pasteIntoDevice() async {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        await send(control: .setClipboard(sequence: 0, paste: true, text: text))
    }

    enum VolumeDirection { case up, down, mute }

    func pressBack() async { await tapKey(AndroidKeyCode.back.rawValue) }
    func pressHome() async { await tapKey(AndroidKeyCode.home.rawValue) }
    func pressRecents() async { await tapKey(187) }
    func pressPower() async { await tapKey(AndroidKeyCode.power.rawValue) }
    func openNotificationPanel() async { await send(control: .expandNotificationPanel) }
    func openSettingsPanel() async { await send(control: .expandSettingsPanel) }
    func rotateDevice() async { await send(control: .rotateDevice) }
    func resetVideoStream() async { await send(control: .resetVideo) }

    func pressVolume(_ direction: VolumeDirection) async {
        let code: Int = switch direction {
        case .up: AndroidKeyCode.volumeUp.rawValue
        case .down: AndroidKeyCode.volumeDown.rawValue
        case .mute: 164
        }
        await tapKey(code)
    }

    func saveScreenshot() async {
        let service = ScreenshotService(adbService: adbService)
        do {
            let url = try await service.saveScreenshotToDownloads(deviceId: adbId, deviceName: deviceName)
            lastScreenshotURL = url
        } catch {
            lastScreenshotURL = nil
        }
    }

    private func tapKey(_ rawKeycode: Int) async {
        let code = Int32(rawKeycode)
        await send(control: .injectKeycode(action: .down, keycode: code, repeatCount: 0, metaState: 0))
        await send(control: .injectKeycode(action: .up, keycode: code, repeatCount: 0, metaState: 0))
    }

    private func startBatteryPolling() {
        batteryTask?.cancel()
        batteryTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshBattery()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func refreshBattery() async {
        do {
            let output = try await adbService.shell("dumpsys battery | grep level", deviceId: adbId)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if let range = trimmed.range(of: "level:"),
               let value = Int(trimmed[range.upperBound...].trimmingCharacters(in: .whitespaces)) {
                batteryLevel = value
            }
        } catch {
            // silent: device may have disconnected
        }
    }

    private func setupDecoder(width: Int, height: Int) {
        let decoder = H264Decoder(width: width, height: height)
        decoder?.onSampleBuffer = { [weak self] sampleBuffer in
            self?.renderer.enqueue(sampleBuffer)
        }
        decoder?.onError = { [weak self] status in
            self?.state = .error(.decoderFailed(status))
        }
        self.decoder = decoder
    }

    private func updateMetricsIfNeeded() {
        let elapsed = Date().timeIntervalSince(windowStart)
        if elapsed >= 1.0 {
            fps = Double(packetsInWindow) / elapsed
            bitrate = Int(Double(bytesInWindow * 8) / elapsed)
            packetsInWindow = 0
            bytesInWindow = 0
            windowStart = Date()
        }
    }

    private func onStreamEnded() async {
        if case .streaming = state {
            state = .disconnected
        }
        await stop()
    }

    private func finish() async {
        onFinished?(self)
        onFinished = nil
    }
}
