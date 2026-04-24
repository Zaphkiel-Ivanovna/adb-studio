import Foundation

struct ServerLaunchResult {
    let process: Process
    let stdout: Pipe
    let stderr: Pipe
    let remoteJarPath: String
}

struct ServerLauncher {
    let adbService: ADBService

    /// Push the bundled scrcpy-server jar, then launch `app_process` with the parsed options.
    /// The caller owns the returned `Process` and is responsible for its lifecycle.
    /// `scid` must match the socket name used by the transport (so server and client agree).
    func launch(
        deviceId: String,
        parameters: ServerParameters,
        scid: Int32,
        onLog: @escaping (String) -> Void = { _ in }
    ) async throws -> ServerLaunchResult {
        guard let bundleURL = Bundle.main.url(forResource: "scrcpy-server", withExtension: nil) else {
            throw MirroringError.serverBundleMissing
        }

        let remotePath = "/data/local/tmp/scrcpy-server-\(UUID().uuidString.lowercased())"
        do {
            try await adbService.push(localPath: bundleURL, remotePath: remotePath, deviceId: deviceId)
        } catch {
            throw MirroringError.serverPushFailed(error.localizedDescription)
        }

        var args = [
            "CLASSPATH=\(remotePath)",
            "app_process",
            "/",
            "com.genymobile.scrcpy.Server",
            ServerParameters.scrcpyServerVersion
        ]
        args.append(contentsOf: parameters.toArguments(scid: scid))

        let handle: ShellProcessHandle
        do {
            handle = try adbService.shellRawProcess(deviceId: deviceId, arguments: args)
        } catch {
            throw MirroringError.serverLaunchFailed(error.localizedDescription)
        }

        handle.stdout.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.split(separator: "\n") where !line.isEmpty {
                onLog("[stdout] \(line)")
            }
        }
        handle.stderr.fileHandleForReading.readabilityHandler = { fh in
            let data = fh.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.split(separator: "\n") where !line.isEmpty {
                onLog("[stderr] \(line)")
            }
        }

        do {
            try handle.process.run()
        } catch {
            handle.stdout.fileHandleForReading.readabilityHandler = nil
            handle.stderr.fileHandleForReading.readabilityHandler = nil
            throw MirroringError.serverLaunchFailed(error.localizedDescription)
        }

        return ServerLaunchResult(
            process: handle.process,
            stdout: handle.stdout,
            stderr: handle.stderr,
            remoteJarPath: remotePath
        )
    }

    func cleanup(result: ServerLaunchResult, deviceId: String) async {
        result.stdout.fileHandleForReading.readabilityHandler = nil
        result.stderr.fileHandleForReading.readabilityHandler = nil

        if result.process.isRunning {
            result.process.terminate()
        }

        _ = try? await adbService.shell("rm -f \(result.remoteJarPath)", deviceId: deviceId)
    }
}
