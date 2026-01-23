import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case adb = "ADB"
        case network = "Network"
        case about = "About"

        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .adb: return "terminal.fill"
            case .network: return "wifi"
            case .about: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsTab(settingsStore: settingsStore)
                    case .adb:
                        ADBSettingsTab(settingsStore: settingsStore)
                    case .network:
                        NetworkSettingsTab(settingsStore: settingsStore)
                    case .about:
                        AboutSettingsTab()
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                TabButton(
                    title: tab.rawValue,
                    icon: tab.icon,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color.accentColor : Color.clear)
                    .foregroundColor(isSelected ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "DEVICE MONITORING") {
                SettingsRow(
                    title: "Refresh cadence",
                    description: "How often ADB Studio polls for connected devices"
                ) {
                    Picker("", selection: Binding(
                        get: { settingsStore.settings.refreshInterval },
                        set: { newValue in settingsStore.update { $0.refreshInterval = newValue } }
                    )) {
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                        Text("3s").tag(3.0)
                        Text("5s").tag(5.0)
                        Text("10s").tag(10.0)
                    }
                    .frame(width: 80)
                }

                SettingsToggle(
                    title: "Show connection notifications",
                    description: "Display alerts when devices connect or disconnect",
                    isOn: Binding(
                        get: { settingsStore.settings.showConnectionNotifications },
                        set: { newValue in settingsStore.update { $0.showConnectionNotifications = newValue } }
                    )
                )
            }

            SettingsSection(title: "STARTUP") {
                SettingsToggle(
                    title: "Auto-connect to last devices",
                    description: "Automatically reconnect to previously connected WiFi devices on launch",
                    isOn: Binding(
                        get: { settingsStore.settings.autoConnectLastDevices },
                        set: { newValue in settingsStore.update { $0.autoConnectLastDevices = newValue } }
                    )
                )
            }

            SettingsSection(title: "SCREENSHOTS") {
                SettingsRow(
                    title: "Save location",
                    description: "Default folder for saved screenshots"
                ) {
                    Picker("", selection: Binding(
                        get: { settingsStore.settings.screenshotSaveLocation },
                        set: { newValue in settingsStore.update { $0.screenshotSaveLocation = newValue } }
                    )) {
                        ForEach(AppSettings.ScreenshotLocation.allCases.filter { $0 != .custom }, id: \.self) { loc in
                            Text(loc.displayName).tag(loc)
                        }
                    }
                    .frame(width: 120)
                }
            }
        }
    }
}

// MARK: - ADB Tab

struct ADBSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var detectedPath: String = "Searching..."

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "ADB EXECUTABLE") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-detected path")
                                .font(.system(size: 13, weight: .medium))
                            Text(detectedPath)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(detectedPath == "Not found" ? .red : .secondary)
                        }
                        Spacer()
                        if detectedPath != "Not found" && detectedPath != "Searching..." {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }

                SettingsToggle(
                    title: "Use custom ADB path",
                    description: "Override the auto-detected ADB executable location",
                    isOn: Binding(
                        get: { settingsStore.settings.useCustomADBPath },
                        set: { newValue in settingsStore.update { $0.useCustomADBPath = newValue } }
                    )
                )

                if settingsStore.settings.useCustomADBPath {
                    HStack(spacing: 8) {
                        TextField("/path/to/adb", text: Binding(
                            get: { settingsStore.settings.customADBPath ?? "" },
                            set: { newValue in settingsStore.update { $0.customADBPath = newValue.isEmpty ? nil : newValue } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))

                        Button("Browse...") {
                            browseForADB()
                        }
                    }
                }
            }
        }
        .onAppear {
            detectADBPath()
        }
    }

    private func detectADBPath() {
        if let path = ShellExecutor.findADBPath() {
            detectedPath = path
        } else {
            detectedPath = "Not found"
        }
    }

    private func browseForADB() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Select ADB executable"

        if panel.runModal() == .OK, let url = panel.url {
            settingsStore.update { $0.customADBPath = url.path }
        }
    }
}

// MARK: - Network Tab

struct NetworkSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "TCP/IP CONNECTION") {
                SettingsRow(
                    title: "Default port",
                    description: "Port used when connecting to devices over WiFi"
                ) {
                    TextField("5555", text: Binding(
                        get: { String(settingsStore.settings.defaultTcpipPort) },
                        set: {
                            if let port = Int($0) {
                                settingsStore.update { $0.defaultTcpipPort = port }
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - About Tab

struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            VStack(spacing: 4) {
                Text("ADB Studio")
                    .font(.title2.bold())
                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("A native macOS app for managing\nAndroid devices via ADB")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/Zaphkiel-Ivanovna/adb-studio")!) {
                    Label("View on GitHub", systemImage: "link")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            Spacer()

            Text("© 2025 ZaphkielIvanovna. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reusable Components

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 16) {
                content
            }
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .controlSize(.large)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let control: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            control
        }
    }
}

#Preview {
    SettingsView(settingsStore: SettingsStore())
}
