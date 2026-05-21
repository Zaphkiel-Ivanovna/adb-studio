import Foundation

// MARK: - Public Types

struct ShellResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32

    var isSuccess: Bool { exitCode == 0 }

    var combinedOutput: String {
        errorOutput.isEmpty ? output : output + "\n" + errorOutput
    }
}

protocol ShellExecuting {
    func execute(_ command: String, arguments: [String], timeout: TimeInterval) async throws -> ShellResult
    func executeRaw(_ command: String, arguments: [String], timeout: TimeInterval) async throws -> Data
}

// MARK: - ShellExecutor

final class ShellExecutor: ShellExecuting {

    // MARK: - Public API

    func execute(_ command: String, arguments: [String] = [], timeout: TimeInterval = 30.0) async throws -> ShellResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = Self.buildEnvironment()

        try process.run()

        let timedOut = await Self.raceProcessAgainstTimeout(process, timeout: timeout)

        if timedOut {
            print("⏱️ TIMEOUT after \(timeout)s: \(command) \(arguments.joined(separator: " "))")
            throw ADBError.timeout
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        return ShellResult(
            output: String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            errorOutput: String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            exitCode: process.terminationStatus
        )
    }

    func executeRaw(_ command: String, arguments: [String] = [], timeout: TimeInterval = 30.0) async throws -> Data {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = Self.buildEnvironment()

        let accumulator = DataAccumulator()
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                accumulator.append(data)
            }
        }

        do {
            try process.run()
        } catch {
            outputHandle.readabilityHandler = nil
            throw error
        }

        let timedOut = await Self.raceProcessAgainstTimeout(process, timeout: timeout)

        outputHandle.readabilityHandler = nil
        let finalData = accumulator.finalize(with: outputHandle.readDataToEndOfFile())

        if timedOut {
            print("⏱️ RAW TIMEOUT after \(timeout)s: \(command) \(arguments.joined(separator: " "))")
            throw ADBError.timeout
        }

        if process.terminationStatus != 0 {
            throw ADBError.commandFailed(arguments.joined(separator: " "), process.terminationStatus)
        }

        return finalData
    }

    // MARK: - ADB Discovery

    static func findADBPath() -> String? {
        let possiblePaths = [
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
            "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
        ]

        for path in possiblePaths where FileManager.default.fileExists(atPath: path) {
            return path
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["adb"]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let path = path, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
                return path
            }
        } catch {}

        return nil
    }

    // MARK: - Private Helpers

    /// Returns true if `process` (already launched) had to be terminated for exceeding `timeout`.
    private static func raceProcessAgainstTimeout(_ process: Process, timeout: TimeInterval) async -> Bool {
        await withTaskGroup(of: TimeoutOutcome.self, returning: Bool.self) { group in
            group.addTask {
                await process.waitUntilExitAsync()
                return .finished
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                if Task.isCancelled { return .finished }
                if process.isRunning {
                    process.terminate()
                    await process.waitUntilExitAsync()
                    return .timedOut
                }
                return .finished
            }
            let first = await group.next() ?? .finished
            group.cancelAll()
            for await _ in group {}
            return first == .timedOut
        }
    }

    private static func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/Users/\(NSUserName())/Library/Android/sdk/platform-tools"
        ]
        let currentPath = env["PATH"] ?? ""
        env["PATH"] = (additionalPaths + [currentPath]).joined(separator: ":")
        return env
    }
}

// MARK: - File-Private Helpers

private enum TimeoutOutcome { case finished, timedOut }

/// Thread-safe accumulator for streamed shell output.
private final class DataAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func finalize(with finalData: Data) -> Data {
        lock.lock()
        data.append(finalData)
        let result = data
        lock.unlock()
        return result
    }
}

/// Resumes a `CheckedContinuation` exactly once across concurrent callers.
private final class ContinuationLatch: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private let continuation: CheckedContinuation<Void, Never>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        continuation.resume()
    }
}

private extension Process {
    /// Awaits exit, handling the race where the process ends before the handler is installed.
    func waitUntilExitAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let latch = ContinuationLatch(continuation)
            self.terminationHandler = { _ in latch.resume() }
            if !self.isRunning { latch.resume() }
        }
    }
}
