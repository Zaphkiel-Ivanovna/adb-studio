import Foundation
import AppKit

final class ScreenshotService {
    private let adbService: ADBService

    init(adbService: ADBService) {
        self.adbService = adbService
    }

    func takeScreenshot(deviceId: String) async throws -> NSImage {
        let data = try await adbService.takeScreenshot(deviceId: deviceId)

        guard let image = NSImage(data: data) else {
            throw ADBError.parseError("Failed to create image from screenshot data")
        }

        return image
    }

    func takeScreenshotToClipboard(deviceId: String) async throws {
        let image = try await takeScreenshot(deviceId: deviceId)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        guard pasteboard.writeObjects([image]) else {
            throw ADBError.commandFailed("copy to clipboard", -1)
        }
    }

    func saveScreenshot(deviceId: String, to url: URL) async throws {
        let data = try await adbService.takeScreenshot(deviceId: deviceId)

        try data.write(to: url)
    }

    func saveScreenshotToDownloads(deviceId: String, deviceName: String) async throws -> URL {
        let data = try await adbService.takeScreenshot(deviceId: deviceId)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let safeName = deviceName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")

        let filename = "screenshot_\(safeName)_\(timestamp).png"

        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsURL.appendingPathComponent(filename)

        try data.write(to: fileURL)

        return fileURL
    }
}
