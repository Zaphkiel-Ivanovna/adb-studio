import SwiftUI

/// First-run transparency notice for crash & error reporting.
///
/// Reporting is enabled by default (opt-out). This sheet informs the user up front what is and is
/// not sent, and lets them disable it in one click. Whatever they choose is persisted as a
/// non-`.unknown` value so the sheet never shows again. It can be toggled later in Settings › General.
struct CrashReportingConsentSheet: View {
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "ladybug.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white, .red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Help improve ADB Studio")
                        .font(.title2.bold())
                    Text("Anonymous crash & error reporting")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Text("To catch crashes like the one that could occur during device polling, "
                + "ADB Studio can send anonymous diagnostic reports. It is on by default and "
                + "you can turn it off anytime — now or in Settings › General.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                infoRow(symbol: "checkmark.circle.fill", tint: .green, title: "What is sent",
                        detail: "Scrubbed crash stack traces, error categories, app & macOS version, "
                            + "and a random installation ID.")
                infoRow(symbol: "xmark.circle.fill", tint: .red, title: "What is never sent",
                        detail: "Device serials, IP addresses, file paths, clipboard contents, "
                            + "pairing codes, or device names.")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            HStack {
                Button("Disable") { choose(.denied) }
                Spacer()
                Button("Keep enabled") { choose(.granted) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func infoRow(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func choose(_ consent: AppSettings.CrashReportingConsent) {
        settingsStore.update { $0.crashReportingConsent = consent }
        dismiss()
    }
}

#Preview {
    CrashReportingConsentSheet(settingsStore: SettingsStore())
}
