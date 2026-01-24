import SwiftUI

struct InstalledAppRow: View {
    let app: InstalledApp
    let isActioning: Bool
    let onAction: (AppAction) -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            appIcon

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(app.effectiveDisplayName)
                        .font(.system(.body, design: .default, weight: .medium))
                        .lineLimit(1)

                    if !app.isEnabled {
                        badgeView("Disabled", color: .orange)
                    }

                    if app.isSystemApp {
                        badgeView("System", color: .secondary)
                    }
                }

                Text(app.packageName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let version = app.versionName {
                    HStack(spacing: 8) {
                        Text("v\(version)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if let updateTime = app.updateTime {
                            Text("Updated: \(Self.dateFormatter.string(from: updateTime))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if let installTime = app.installTime {
                            Text("Installed: \(Self.dateFormatter.string(from: installTime))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            if isActioning {
                ProgressView()
                    .controlSize(.small)
            } else {
                actionMenu
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(app.isSystemApp ? Color.gray.opacity(0.15) : Color.accentColor.opacity(0.15))
                .frame(width: 36, height: 36)

            Image(systemName: app.isSystemApp ? "gear" : "app.fill")
                .font(.system(size: 18))
                .foregroundColor(app.isSystemApp ? .secondary : .accentColor)
        }
    }

    private func badgeView(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }

    private var actionMenu: some View {
        Menu {
            Button {
                onAction(.launch)
            } label: {
                Label(AppAction.launch.displayName, systemImage: AppAction.launch.systemImage)
            }

            Button {
                onAction(.forceStop)
            } label: {
                Label(AppAction.forceStop.displayName, systemImage: AppAction.forceStop.systemImage)
            }

            Divider()

            Button(role: .destructive) {
                onAction(.uninstall)
            } label: {
                Label(AppAction.uninstall.displayName, systemImage: AppAction.uninstall.systemImage)
            }

            Button(role: .destructive) {
                onAction(.uninstallKeepData)
            } label: {
                Label(AppAction.uninstallKeepData.displayName, systemImage: AppAction.uninstallKeepData.systemImage)
            }

            Divider()

            if app.isEnabled {
                Button(role: .destructive) {
                    onAction(.disable)
                } label: {
                    Label(AppAction.disable.displayName, systemImage: AppAction.disable.systemImage)
                }
            } else {
                Button {
                    onAction(.enable)
                } label: {
                    Label(AppAction.enable.displayName, systemImage: AppAction.enable.systemImage)
                }
            }

            Button {
                onAction(.openSettings)
            } label: {
                Label(AppAction.openSettings.displayName, systemImage: AppAction.openSettings.systemImage)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28, height: 28)
    }
}
