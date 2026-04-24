import SwiftUI

struct MirroringTabView: View {
    let deviceId: String

    @EnvironmentObject private var mirroringManager: MirroringManager
    @EnvironmentObject private var deviceManager: DeviceManager
    @Environment(\.openWindow) private var openWindow

    @State private var isStarting = false
    @State private var startError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let session = mirroringManager.session(for: deviceId) {
                activeSessionCard(session: session)
            } else {
                idleCard
            }

            if let startError {
                Label(startError, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundColor(.red)
            }

            if !mirroringManager.isAvailable {
                Label("ADB is not available — install Android Platform Tools to enable mirroring.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var idleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "display")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mirror this device")
                        .font(.headline)
                    Text("Stream the device display and interact with it from macOS.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                startSession()
            } label: {
                HStack {
                    if isStarting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isStarting ? "Starting…" : "Open Mirror Window")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isStarting || !mirroringManager.isAvailable)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func activeSessionCard(session: MirroringSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "display")
                    .font(.system(size: 28))
                    .foregroundColor(stateAccent(session.state))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mirroring active")
                        .font(.headline)
                    Text(stateLabel(session.state))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 24) {
                metric(label: "FPS", value: String(format: "%.0f", session.fps))
                metric(label: "Bitrate", value: formatBitrate(Double(session.bitrate)))
                metric(label: "Resolution", value: formatResolution(session.resolution))
            }

            HStack(spacing: 8) {
                Button {
                    openWindow(id: "mirror", value: deviceId)
                } label: {
                    Label("Focus Window", systemImage: "macwindow.on.rectangle")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    Task { await mirroringManager.stopSession(adbId: deviceId) }
                } label: {
                    Label("Stop Mirroring", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit())
                .fontWeight(.medium)
        }
    }

    private func startSession() {
        guard let device = deviceManager.devices.first(where: { $0.allAdbIds.contains(deviceId) }) else {
            startError = "Device no longer connected."
            return
        }
        isStarting = true
        startError = nil
        Task {
            do {
                _ = try await mirroringManager.startSession(for: device)
                openWindow(id: "mirror", value: deviceId)
            } catch {
                startError = error.localizedDescription
            }
            isStarting = false
        }
    }

    private func stateLabel(_ state: MirroringSession.State) -> String {
        switch state {
        case .idle: return "Idle"
        case .connecting: return "Connecting…"
        case .streaming: return "Streaming"
        case .disconnected: return "Disconnected"
        case .error(let err): return err.errorDescription ?? "Error"
        }
    }

    private func stateAccent(_ state: MirroringSession.State) -> Color {
        switch state {
        case .streaming: return .green
        case .connecting: return .yellow
        case .disconnected: return .orange
        case .error: return .red
        case .idle: return .gray
        }
    }

    private func formatBitrate(_ bps: Double) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f Mbps", bps / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0f kbps", bps / 1_000) }
        return "—"
    }

    private func formatResolution(_ size: CGSize?) -> String {
        guard let size, size.width > 0, size.height > 0 else { return "—" }
        return "\(Int(size.width))×\(Int(size.height))"
    }
}
