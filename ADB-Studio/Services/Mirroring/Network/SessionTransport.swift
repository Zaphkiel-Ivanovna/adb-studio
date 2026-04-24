import Foundation
import Network

actor SessionTransport {
    struct Config {
        let deviceId: String
        let scid: Int32
        let adbService: ADBService
        let handshakeTimeout: TimeInterval

        init(deviceId: String, scid: Int32, adbService: ADBService, handshakeTimeout: TimeInterval = 10) {
            self.deviceId = deviceId
            self.scid = scid
            self.adbService = adbService
            self.handshakeTimeout = handshakeTimeout
        }
    }

    enum Event: Sendable {
        case ready(DeviceMeta)
        case video(VideoPacket)
        case clipboard(String)
        case disconnected
        case error(MirroringError)
    }

    private let config: Config
    private let socketName: String

    private var listener: NWListener?
    private var pendingConnections: [NWConnection] = []
    private var acceptWaiters: [CheckedContinuation<NWConnection, Error>] = []
    private var videoConnection: NWConnection?
    private var controlConnection: NWConnection?
    private var reverseRegistered = false

    private var eventContinuation: AsyncStream<Event>.Continuation?
    private var runTask: Task<Void, Never>?

    init(config: Config) {
        self.config = config
        self.socketName = ServerParameters.socketName(for: config.scid)
    }

    var reverseSocketName: String { socketName }

    /// Starts listener + adb reverse + handshake. Returns a stream of events.
    /// Caller should start consuming the stream immediately.
    func run() -> AsyncStream<Event> {
        let (stream, continuation) = AsyncStream<Event>.makeStream(bufferingPolicy: .bufferingNewest(512))
        self.eventContinuation = continuation
        runTask = Task { [weak self] in
            await self?.execute()
        }
        return stream
    }

    func send(control message: ControlMessage) async throws {
        guard let connection = controlConnection else {
            throw MirroringError.controlSocketClosed
        }
        try await sendAll(message.encode(), on: connection)
    }

    func shutdown() async {
        runTask?.cancel()
        runTask = nil

        eventContinuation?.finish()
        eventContinuation = nil

        for waiter in acceptWaiters {
            waiter.resume(throwing: MirroringError.handshakeTimeout)
        }
        acceptWaiters.removeAll()
        for conn in pendingConnections {
            conn.cancel()
        }
        pendingConnections.removeAll()

        videoConnection?.cancel()
        controlConnection?.cancel()
        videoConnection = nil
        controlConnection = nil

        listener?.cancel()
        listener = nil

        if reverseRegistered {
            reverseRegistered = false
            _ = try? await config.adbService.removeReverseForward(localSocketName: socketName, deviceId: config.deviceId)
        }
    }

    private func execute() async {
        do {
            let port = try await startListener()
            try await config.adbService.createReverseForward(
                localSocketName: socketName,
                remotePort: Int(port),
                deviceId: config.deviceId
            )
            reverseRegistered = true

            let videoConn = try await acceptNextConnection(timeout: config.handshakeTimeout)
            let controlConn = try await acceptNextConnection(timeout: config.handshakeTimeout)

            self.videoConnection = videoConn
            self.controlConnection = controlConn

            let meta = try await readDeviceMeta(from: videoConn)
            eventContinuation?.yield(.ready(meta))

            Task { [weak self] in await self?.runDeviceMessageReader(on: controlConn) }

            await runPacketReader(on: videoConn)
        } catch let error as MirroringError {
            eventContinuation?.yield(.error(error))
            eventContinuation?.finish()
        } catch {
            eventContinuation?.yield(.error(.serverLaunchFailed(error.localizedDescription)))
            eventContinuation?.finish()
        }
    }

    private func startListener() async throws -> UInt16 {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.onNewConnection(connection) }
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UInt16, Error>) in
            var resumed = false
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !resumed else { return }
                    resumed = true
                    let port = listener.port?.rawValue ?? 0
                    continuation.resume(returning: port)
                case .failed(let error):
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
        }
    }

    private func onNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                Task { await self?.deliverConnection(connection) }
            case .failed, .cancelled:
                Task { await self?.discardConnection(connection) }
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }

    private func deliverConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = nil
        if let waiter = acceptWaiters.first {
            acceptWaiters.removeFirst()
            waiter.resume(returning: connection)
        } else {
            pendingConnections.append(connection)
        }
    }

    private func discardConnection(_ connection: NWConnection) {
        pendingConnections.removeAll { $0 === connection }
    }

    private func acceptNextConnection(timeout: TimeInterval) async throws -> NWConnection {
        if !pendingConnections.isEmpty {
            return pendingConnections.removeFirst()
        }

        return try await withThrowingTaskGroup(of: NWConnection.self) { group in
            group.addTask { [self] in
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NWConnection, Error>) in
                    Task { await self.enqueueWaiter(continuation) }
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw MirroringError.handshakeTimeout
            }

            guard let result = try await group.next() else {
                throw MirroringError.handshakeTimeout
            }
            group.cancelAll()
            return result
        }
    }

    private func enqueueWaiter(_ continuation: CheckedContinuation<NWConnection, Error>) {
        if !pendingConnections.isEmpty {
            let connection = pendingConnections.removeFirst()
            continuation.resume(returning: connection)
            return
        }
        acceptWaiters.append(continuation)
    }

    private func readDeviceMeta(from connection: NWConnection) async throws -> DeviceMeta {
        let nameBytes = try await readExactly(connection, DeviceMeta.deviceNameSize)
        let codecBytes = try await readExactly(connection, DeviceMeta.codecHeaderSize)
        do {
            return try DeviceMeta(deviceName: nameBytes, codecHeader: codecBytes)
        } catch {
            throw MirroringError.invalidDeviceMeta(String(describing: error))
        }
    }

    private func runDeviceMessageReader(on connection: NWConnection) async {
        while !Task.isCancelled {
            do {
                let message = try await DeviceMessage.read(from: connection)
                switch message {
                case .clipboard(let text):
                    eventContinuation?.yield(.clipboard(text))
                case .ackClipboard, .unsupported:
                    continue
                }
            } catch {
                return
            }
        }
    }

    private func runPacketReader(on connection: NWConnection) async {
        while !Task.isCancelled {
            do {
                let packet = try await VideoPacket.read(from: connection)
                eventContinuation?.yield(.video(packet))
            } catch VideoPacketError.connectionClosed {
                eventContinuation?.yield(.disconnected)
                eventContinuation?.finish()
                return
            } catch {
                eventContinuation?.yield(.error(.videoSocketClosed))
                eventContinuation?.finish()
                return
            }
        }
    }

    private func sendAll(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}
