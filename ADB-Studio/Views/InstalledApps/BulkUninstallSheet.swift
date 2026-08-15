import SwiftUI

struct BulkUninstallSheet: View {
    @ObservedObject var viewModel: InstalledAppsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            switch viewModel.bulkPhase {
            case .confirming:
                confirmingView
            case .running(let current, let total, let appName):
                runningView(current: current, total: total, appName: appName)
            case .finished(let succeeded, let failures, let skipped):
                finishedView(succeeded: succeeded, failures: failures, skipped: skipped)
            }
        }
        .padding(24)
        .frame(width: 420)
        .interactiveDismissDisabled(viewModel.isBulkUninstalling)
    }

    // MARK: - Confirming

    private var confirmingView: some View {
        let apps = viewModel.selectedApps
        let systemAppCount = viewModel.selectedSystemAppCount

        return VStack(spacing: 20) {
            header(
                symbol: "trash",
                tint: .red,
                title: apps.count == 1 ? "Uninstall 1 app?" : "Uninstall \(apps.count) apps?",
                subtitle: "This cannot be undone."
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(apps) { app in
                        HStack(spacing: 8) {
                            Text(app.effectiveDisplayName)
                                .font(.system(size: 12, weight: .medium))
                            Text(app.packageName)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Spacer()
                            if app.isSystemApp {
                                Text("System")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)

            if systemAppCount > 0 {
                warningLabel(
                    systemAppCount == 1
                        ? "1 system app is selected. Android usually refuses to uninstall these — it will be reported as a failure."
                        : "\(systemAppCount) system apps are selected. Android usually refuses to uninstall these — they will be reported as failures."
                )
            }

            Toggle("Keep app data and cache", isOn: $viewModel.bulkKeepData)
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Uninstall", role: .destructive) {
                    viewModel.confirmBulkUninstall()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Running

    private func runningView(current: Int, total: Int, appName: String) -> some View {
        VStack(spacing: 20) {
            header(
                symbol: "trash",
                tint: .red,
                title: "Uninstalling \(current) of \(total)",
                subtitle: appName
            )

            ProgressView(value: Double(current - 1), total: Double(total))
                .progressViewStyle(.linear)

            Button(viewModel.isBulkStopRequested ? "Cancelling…" : "Cancel") {
                viewModel.requestBulkUninstallStop()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(viewModel.isBulkStopRequested)

            Text(
                viewModel.isBulkStopRequested
                    ? "Stopping after the current app finishes."
                    : "The app being uninstalled will finish first."
            )
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Finished

    private func finishedView(succeeded: Int, failures: [BulkUninstallFailure], skipped: Int) -> some View {
        VStack(spacing: 20) {
            header(
                symbol: failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                tint: failures.isEmpty ? .green : .orange,
                title: failures.isEmpty ? "Done" : "Finished with \(failures.count) failed",
                subtitle: succeeded == 1 ? "1 app uninstalled" : "\(succeeded) apps uninstalled"
            )

            if skipped > 0 {
                Text(skipped == 1 ? "1 app was not attempted." : "\(skipped) apps were not attempted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !failures.isEmpty {
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(failures) { failure in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(failure.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                Text(failure.message)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Shared Chrome

    private func header(symbol: String, tint: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundColor(tint)

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    private func warningLabel(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 12))
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
}
