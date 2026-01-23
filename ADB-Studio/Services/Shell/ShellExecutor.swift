import Foundation

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

final class ShellExecutor: ShellExecuting {

    func execute(_ command: String, arguments: [String] = [], timeout: TimeInterval = 30.0) async throws -> ShellResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.environment = Self.buildEnvironment()

            var timedOut = false
            let timeoutWorkItem = DispatchWorkItem {
                timedOut = true
                process.terminate()
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

            do {
                try process.run()
                process.waitUntilExit()

                timeoutWorkItem.cancel()

                if timedOut {
                    print("⏱️ TIMEOUT after \(timeout)s: \(command) \(arguments.joined(separator: " "))")
                    continuation.resume(throwing: ADBError.timeout)
                    return
                }

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let result = ShellResult(
                    output: String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    errorOutput: String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                    exitCode: process.terminationStatus
                )

                continuation.resume(returning: result)
            } catch {
                timeoutWorkItem.cancel()
                continuation.resume(throwing: error)
            }
        }
    }

    func executeRaw(_ command: String, arguments: [String] = [], timeout: TimeInterval = 30.0) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.environment = Self.buildEnvironment()

            var timedOut = false

            let timeoutWorkItem = DispatchWorkItem {
                timedOut = true
                process.terminate()
            }

            let dataLock = NSLock()
            var outputData = Data()

            // Drain pipe buffer while process runs to avoid deadlock
            let outputHandle = outputPipe.fileHandleForReading
            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    dataLock.lock()
                    outputData.append(data)
                    dataLock.unlock()
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)

            do {
                try process.run()
                process.waitUntilExit()

                outputHandle.readabilityHandler = nil

                dataLock.lock()
                outputData.append(outputHandle.readDataToEndOfFile())
                let finalData = outputData
                dataLock.unlock()

                timeoutWorkItem.cancel()

                if timedOut {
                    print("⏱️ RAW TIMEOUT after \(timeout)s: \(command) \(arguments.joined(separator: " "))")
                    continuation.resume(throwing: ADBError.timeout)
                    return
                }

                if process.terminationStatus != 0 {
                    continuation.resume(throwing: ADBError.commandFailed(arguments.joined(separator: " "), process.terminationStatus))
                    return
                }

                continuation.resume(returning: finalData)
            } catch {
                timeoutWorkItem.cancel()
                outputHandle.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
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

    static func findADBPath() -> String? {
        let possiblePaths = [
            "/usr/local/bin/adb",
            "/opt/homebrew/bin/adb",
            "/Users/\(NSUserName())/Library/Android/sdk/platform-tools/adb"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
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
}
