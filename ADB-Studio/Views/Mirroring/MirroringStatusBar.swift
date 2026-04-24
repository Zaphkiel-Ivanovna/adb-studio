import SwiftUI

struct MirroringStatusBar: View {
    @ObservedObject var session: MirroringSession

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 8, height: 8)
                Text(stateLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if case .streaming = session.state {
                Divider().frame(height: 12)
                statusItem(label: "FPS", value: String(format: "%.0f", session.fps))
                statusItem(label: "Bitrate", value: formattedBitrate)
                statusItem(label: "Resolution", value: formattedResolution)
                if let battery = session.batteryLevel {
                    Divider().frame(height: 12)
                    batteryItem(battery)
                }
            }

            Spacer()

            if case .error(let err) = session.state {
                Label(err.errorDescription ?? "Error", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
    }

    private func batteryItem(_ level: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: batteryIcon(level))
                .font(.caption)
                .foregroundColor(batteryColor(level))
            Text("\(level)%")
                .font(.caption.monospacedDigit())
                .foregroundColor(.primary)
        }
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case ..<15: return "battery.0"
        case ..<40: return "battery.25"
        case ..<70: return "battery.50"
        case ..<90: return "battery.75"
        default: return "battery.100"
        }
    }

    private func batteryColor(_ level: Int) -> Color {
        level < 20 ? .red : .secondary
    }

    private func statusItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundColor(.primary)
        }
    }

    private var stateColor: Color {
        switch session.state {
        case .idle: return .gray
        case .connecting: return .yellow
        case .streaming: return .green
        case .disconnected: return .orange
        case .error: return .red
        }
    }

    private var stateLabel: String {
        switch session.state {
        case .idle: return "Idle"
        case .connecting: return "Connecting…"
        case .streaming: return "Streaming"
        case .disconnected: return "Disconnected"
        case .error: return "Error"
        }
    }

    private var formattedBitrate: String {
        let bps = Double(session.bitrate)
        if bps >= 1_000_000 {
            return String(format: "%.1f Mbps", bps / 1_000_000)
        } else if bps >= 1_000 {
            return String(format: "%.0f kbps", bps / 1_000)
        } else {
            return String(format: "%.0f bps", bps)
        }
    }

    private var formattedResolution: String {
        guard let size = session.resolution, size.width > 0, size.height > 0 else { return "—" }
        return "\(Int(size.width))×\(Int(size.height))"
    }
}
