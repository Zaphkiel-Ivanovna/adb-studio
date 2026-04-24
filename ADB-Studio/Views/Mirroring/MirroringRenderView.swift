import SwiftUI
import AppKit

struct MirroringRenderView: NSViewRepresentable {
    let session: MirroringSession
    var rightClickOpensMenu: Bool = false

    func makeNSView(context: Context) -> MirroringNSView {
        let view = MirroringNSView()
        view.session = session
        view.rightClickOpensMenu = rightClickOpensMenu
        view.attachRendererLayer(session.renderer.layer)
        return view
    }

    func updateNSView(_ nsView: MirroringNSView, context: Context) {
        nsView.session = session
        nsView.rightClickOpensMenu = rightClickOpensMenu
        nsView.attachRendererLayer(session.renderer.layer)
    }
}

final class MirroringNSView: NSView {
    weak var session: MirroringSession?
    var rightClickOpensMenu: Bool = false

    private let throttle = PointerThrottle(maxRateHz: 120)
    private var isPointerDown = false
    private var currentButtons: UInt32 = 0
    private var trackingArea: NSTrackingArea?

    private var isMagnifying = false
    private var magnifyCenter: CGPoint = .zero
    private var magnifyDistance: CGFloat = 0
    private let secondaryPointerId: UInt64 = 1

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let root = CALayer()
        root.backgroundColor = NSColor.black.cgColor
        layer = root
        focusRingType = .none
    }

    required init?(coder: NSCoder) { nil }

    func attachRendererLayer(_ renderedLayer: CALayer) {
        guard let layer else { return }
        if renderedLayer.superlayer === layer { return }
        renderedLayer.removeFromSuperlayer()
        renderedLayer.frame = layer.bounds
        renderedLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer.addSublayer(renderedLayer)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        rebuildTrackingArea()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        rebuildTrackingArea()
    }

    private func rebuildTrackingArea() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseDown(with event: NSEvent) {
        handlePointer(event: event, action: .down, buttonMask: 1)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isPointerDown else { return }
        if !throttle.shouldEmit() { return }
        handlePointer(event: event, action: .move, buttonMask: currentButtons)
    }

    override func mouseUp(with event: NSEvent) {
        handlePointer(event: event, action: .up, buttonMask: 0)
    }

    override func rightMouseDown(with event: NSEvent) {
        if rightClickOpensMenu {
            presentContextMenu(for: event)
            return
        }
        handlePointer(event: event, action: .down, buttonMask: 2)
    }

    override func rightMouseDragged(with event: NSEvent) {
        if rightClickOpensMenu { return }
        guard isPointerDown else { return }
        if !throttle.shouldEmit() { return }
        handlePointer(event: event, action: .move, buttonMask: currentButtons)
    }

    override func rightMouseUp(with event: NSEvent) {
        if rightClickOpensMenu { return }
        handlePointer(event: event, action: .up, buttonMask: 0)
    }

    override func magnify(with event: NSEvent) {
        guard let session, let resolution = session.resolution else { return }
        switch event.phase {
        case .began:
            beginMagnify(at: event.locationInWindow, resolution: resolution)
        case .changed:
            updateMagnify(event: event, resolution: resolution)
        case .ended, .cancelled:
            endMagnify(resolution: resolution)
        default:
            break
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard let session, let resolution = session.resolution, let coords = mappedCoordinates(from: event, deviceSize: resolution) else { return }
        let hScroll = Float(event.scrollingDeltaX / 10.0)
        let vScroll = Float(event.scrollingDeltaY / 10.0)
        let clampedH = max(-1, min(1, hScroll))
        let clampedV = max(-1, min(1, vScroll))

        let message = ControlMessage.injectScroll(
            x: Int32(coords.x),
            y: Int32(coords.y),
            screenWidth: UInt16(clamping: Int(resolution.width)),
            screenHeight: UInt16(clamping: Int(resolution.height)),
            hScroll: clampedH,
            vScroll: clampedV,
            buttons: 0
        )
        Task { await session.send(control: message) }
    }

    override func keyDown(with event: NSEvent) {
        if showShortcutsHelpIfNeeded(event) { return }
        if handleGlobalShortcut(event) { return }
        forwardKey(event, action: .down)
    }

    private func handleGlobalShortcut(_ event: NSEvent) -> Bool {
        guard let session else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags == [.command, .shift] {
            switch event.keyCode {
            case 0x00:
                Task { await session.pressRecents() }
                return true
            case 0x2D:
                Task { await session.openSettingsPanel() }
                return true
            case 0x0F:
                Task { await session.resetVideoStream() }
                return true
            default:
                break
            }
        }

        guard flags == .command else { return false }
        switch event.keyCode {
        case 0x08:
            Task { await session.copyFromDevice() }
            return true
        case 0x09:
            Task { await session.pasteIntoDevice() }
            return true
        case 0x0B:
            Task { await session.pressBack() }
            return true
        case 0x04:
            Task { await session.pressHome() }
            return true
        case 0x2D:
            Task { await session.openNotificationPanel() }
            return true
        case 0x0F:
            Task { await session.rotateDevice() }
            return true
        case 0x2F:
            Task { await session.pressPower() }
            return true
        case 0x01:
            Task { await session.saveScreenshot() }
            return true
        case 0x7E:
            Task { await session.pressVolume(.up) }
            return true
        case 0x7D:
            Task { await session.pressVolume(.down) }
            return true
        case 0x2E:
            Task { await session.pressVolume(.mute) }
            return true
        default:
            return false
        }
    }

    private func showShortcutsHelpIfNeeded(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isShiftSlash = flags == [.command, .shift] && event.keyCode == 0x2C
        let isCommandQuestion = flags == .command && (event.characters == "?")
        guard isShiftSlash || isCommandQuestion else { return false }
        NotificationCenter.default.post(name: .mirroringShowShortcutsHelp, object: session?.adbId)
        return true
    }

    override func keyUp(with event: NSEvent) {
        forwardKey(event, action: .up)
    }

    override func flagsChanged(with event: NSEvent) {
        guard let session else { return }
        let metaState = KeycodeMapper.metaState(from: event.modifierFlags)
        guard let keycode = KeycodeMapper.androidKeycode(for: event.keyCode) else { return }
        guard let mask = Self.modifierMask(for: event.keyCode) else { return }
        let isPressed = event.modifierFlags.contains(mask)
        let action: KeyAction = isPressed ? .down : .up
        let message = ControlMessage.injectKeycode(
            action: action,
            keycode: keycode,
            repeatCount: 0,
            metaState: metaState
        )
        Task { await session.send(control: message) }
    }

    private static func modifierMask(for keyCode: UInt16) -> NSEvent.ModifierFlags? {
        switch keyCode {
        case 0x36, 0x37: return .command
        case 0x38, 0x3C: return .shift
        case 0x3A, 0x3D: return .option
        case 0x3B, 0x3E: return .control
        case 0x39: return .capsLock
        case 0x3F: return .function
        default: return nil
        }
    }

    private func forwardKey(_ event: NSEvent, action: KeyAction) {
        guard let session else { return }
        let metaState = KeycodeMapper.metaState(from: event.modifierFlags)
        if let keycode = KeycodeMapper.androidKeycode(for: event.keyCode) {
            let repeatCount: UInt32 = event.isARepeat ? 1 : 0
            let message = ControlMessage.injectKeycode(
                action: action,
                keycode: keycode,
                repeatCount: repeatCount,
                metaState: metaState
            )
            Task { await session.send(control: message) }
            return
        }

        if action == .down, let text = event.characters, !text.isEmpty, isPrintable(text) {
            let message = ControlMessage.injectText(text)
            Task { await session.send(control: message) }
        }
    }

    private func isPrintable(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { scalar in
            !scalar.properties.isDefaultIgnorableCodePoint && scalar.value >= 0x20 && scalar.value != 0x7F
        }
    }

    private func handlePointer(event: NSEvent, action: MotionAction, buttonMask: UInt32) {
        guard let session, let resolution = session.resolution, let coords = mappedCoordinates(from: event, deviceSize: resolution) else { return }

        switch action {
        case .down:
            isPointerDown = true
            currentButtons = buttonMask
        case .up:
            isPointerDown = false
            currentButtons = 0
        default:
            break
        }

        let pressure: Float = (action == .up) ? 0.0 : 1.0
        let message = ControlMessage.injectTouch(
            action: action,
            pointerId: 0,
            x: Int32(coords.x),
            y: Int32(coords.y),
            screenWidth: UInt16(clamping: Int(resolution.width)),
            screenHeight: UInt16(clamping: Int(resolution.height)),
            pressure: pressure,
            actionButton: buttonMask,
            buttons: currentButtons
        )
        Task { await session.send(control: message) }
    }

    private func mappedCoordinates(from event: NSEvent, deviceSize: CGSize) -> (x: UInt32, y: UInt32)? {
        let local = convert(event.locationInWindow, from: nil)
        let mapper = CoordinateMapper(deviceSize: deviceSize)
        return mapper.map(local, in: bounds.size)
    }

    private func presentContextMenu(for event: NSEvent) {
        guard let session else { return }
        let menu = NSMenu()

        let items: [(String, Selector, Any)] = [
            ("Back", #selector(ctxBack), session),
            ("Home", #selector(ctxHome), session),
            ("Recents", #selector(ctxRecents), session),
            ("Rotate", #selector(ctxRotate), session),
            ("Screenshot", #selector(ctxScreenshot), session),
            ("Reset video stream", #selector(ctxReset), session)
        ]
        for (title, selector, _) in items {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func ctxBack() { Task { [weak self] in await self?.session?.pressBack() } }
    @objc private func ctxHome() { Task { [weak self] in await self?.session?.pressHome() } }
    @objc private func ctxRecents() { Task { [weak self] in await self?.session?.pressRecents() } }
    @objc private func ctxRotate() { Task { [weak self] in await self?.session?.rotateDevice() } }
    @objc private func ctxScreenshot() { Task { [weak self] in await self?.session?.saveScreenshot() } }
    @objc private func ctxReset() { Task { [weak self] in await self?.session?.resetVideoStream() } }

    private func beginMagnify(at locationInWindow: CGPoint, resolution: CGSize) {
        let local = convert(locationInWindow, from: nil)
        guard let mapped = CoordinateMapper(deviceSize: resolution).map(local, in: bounds.size) else { return }
        magnifyCenter = CGPoint(x: CGFloat(mapped.x), y: CGFloat(mapped.y))
        magnifyDistance = min(resolution.width, resolution.height) * 0.15
        isMagnifying = true
        sendMagnifyTouches(action: .pointerDown, resolution: resolution)
    }

    private func updateMagnify(event: NSEvent, resolution: CGSize) {
        guard isMagnifying else { return }
        if !throttle.shouldEmit() { return }
        let maxDimension = min(resolution.width, resolution.height) * 0.45
        let minDimension: CGFloat = 20
        let scale = 1 + CGFloat(event.magnification) * 2
        magnifyDistance = min(max(magnifyDistance * scale, minDimension), maxDimension)
        sendMagnifyTouches(action: .move, resolution: resolution)
    }

    private func endMagnify(resolution: CGSize) {
        guard isMagnifying else { return }
        sendMagnifyTouches(action: .pointerUp, resolution: resolution)
        isMagnifying = false
    }

    private func sendMagnifyTouches(action: MotionAction, resolution: CGSize) {
        guard let session else { return }
        let width = UInt16(clamping: Int(resolution.width))
        let height = UInt16(clamping: Int(resolution.height))

        let p1 = CGPoint(
            x: clamp(magnifyCenter.x - magnifyDistance / 2, min: 0, max: resolution.width - 1),
            y: magnifyCenter.y
        )
        let p2 = CGPoint(
            x: clamp(magnifyCenter.x + magnifyDistance / 2, min: 0, max: resolution.width - 1),
            y: magnifyCenter.y
        )
        let pressure: Float = (action == .pointerUp) ? 0 : 1

        let m1 = ControlMessage.injectTouch(
            action: action,
            pointerId: 0,
            x: Int32(p1.x),
            y: Int32(p1.y),
            screenWidth: width,
            screenHeight: height,
            pressure: pressure,
            actionButton: 0,
            buttons: action == .pointerUp ? 0 : 1
        )
        let m2 = ControlMessage.injectTouch(
            action: action,
            pointerId: secondaryPointerId,
            x: Int32(p2.x),
            y: Int32(p2.y),
            screenWidth: width,
            screenHeight: height,
            pressure: pressure,
            actionButton: 0,
            buttons: action == .pointerUp ? 0 : 1
        )
        Task {
            await session.send(control: m1)
            await session.send(control: m2)
        }
    }

    private func clamp(_ value: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        max(lo, min(hi, value))
    }
}

extension Notification.Name {
    static let mirroringShowShortcutsHelp = Notification.Name("mirroringShowShortcutsHelp")
}
