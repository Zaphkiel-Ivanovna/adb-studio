import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    private let minHeight: CGFloat = 320
    private let maxHeight: CGFloat = 450

    var body: some View {
        TabView {
            SettingsTabContainer(minHeight: minHeight, maxHeight: maxHeight) {
                GeneralSettingsTab(settingsStore: settingsStore)
            }
            .tabItem {
                Label("General", systemImage: "gearshape.fill")
            }

            SettingsTabContainer(minHeight: minHeight, maxHeight: maxHeight) {
                ADBSettingsTab(settingsStore: settingsStore)
            }
            .tabItem {
                Label("ADB", systemImage: "terminal.fill")
            }

            SettingsTabContainer(minHeight: minHeight, maxHeight: maxHeight) {
                NetworkSettingsTab(settingsStore: settingsStore)
            }
            .tabItem {
                Label("Network", systemImage: "wifi")
            }

            AboutSettingsTab()
                .frame(height: minHeight)
                .tabItem {
                    Label("About", systemImage: "info.circle.fill")
                }
        }
        .frame(width: 480)
    }
}

// MARK: - Settings Tab Container

struct SettingsTabContainer<Content: View>: View {
    let minHeight: CGFloat
    let maxHeight: CGFloat
    @ViewBuilder let content: Content

    @State private var contentHeight: CGFloat = 0

    private var effectiveHeight: CGFloat {
        max(minHeight, min(contentHeight, maxHeight))
    }

    var body: some View {
        VStack(spacing: 0) {
            if contentHeight > maxHeight {
                ScrollView {
                    content
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
                        })
                }
                .frame(height: maxHeight)
            } else {
                content
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
                    })
                Spacer(minLength: 0)
            }
        }
        .frame(height: effectiveHeight > 0 ? effectiveHeight : nil)
        .onPreferenceChange(HeightPreferenceKey.self) { height in
            contentHeight = height
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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

                SettingsToggle(
                    title: "Check for updates on launch",
                    description: "Automatically check for new versions when the app starts",
                    isOn: Binding(
                        get: { settingsStore.settings.checkForUpdatesOnLaunch },
                        set: { newValue in settingsStore.update { $0.checkForUpdatesOnLaunch = newValue } }
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
        .padding(24)
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
        .padding(24)
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
    @State private var portText: String = ""
    @State private var portError: String?

    private let validPortRange = 1024...65535

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(title: "TCP/IP CONNECTION") {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsRow(
                        title: "Default port",
                        description: "Port used when connecting to devices over WiFi (1024-65535)"
                    ) {
                        TextField("5555", text: $portText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                            .onChange(of: portText) { _, newValue in
                                validateAndUpdatePort(newValue)
                            }
                    }

                    if let error = portError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(24)
        .onAppear {
            portText = String(settingsStore.settings.defaultTcpipPort)
        }
    }

    private func validateAndUpdatePort(_ value: String) {
        // Allow empty field while typing
        guard !value.isEmpty else {
            portError = nil
            return
        }

        // Check if it's a valid number
        guard let port = Int(value) else {
            portError = "Port must be a number"
            return
        }

        // Check port range
        guard validPortRange.contains(port) else {
            portError = "Port must be between 1024 and 65535"
            return
        }

        // Valid port - clear error and update
        portError = nil
        settingsStore.update { $0.defaultTcpipPort = port }
    }
}

// MARK: - About Tab

struct AboutSettingsTab: View {
    private static let githubURL = URL(string: "https://github.com/Zaphkiel-Ivanovna/adb-studio")
    private static let kofiURL = URL(string: "https://ko-fi.com/T6T4E5BP6")

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            VStack(spacing: 4) {
                Text("ADB Studio")
                    .font(.title2.bold())
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("A native macOS app for managing Android devices via ADB")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                if let url = Self.githubURL {
                    Link(destination: url) {
                        Label("View on GitHub", systemImage: "link")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                if let url = Self.kofiURL {
                    Link(destination: url) {
                        Label("Support on Ko-fi", systemImage: "heart.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.pink)
                }
            }
            .padding(.top, 8)

            Spacer()

            Text("© 2025 ZaphkielIvanovna. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .top)
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
