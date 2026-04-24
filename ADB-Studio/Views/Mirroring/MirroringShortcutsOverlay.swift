import SwiftUI

struct MirroringShortcutsOverlay: View {
    let onDismiss: () -> Void

    private let sections: [Section] = [
        Section(title: "Navigation", entries: [
            ("⌘B", "Back"),
            ("⌘H", "Home"),
            ("⌘⇧A", "Recents"),
            ("⌘N", "Notification panel"),
            ("⌘⇧N", "Quick settings"),
            ("⌘R", "Rotate device"),
            ("⌘.", "Lock device")
        ]),
        Section(title: "Volume", entries: [
            ("⌘↑", "Volume up"),
            ("⌘↓", "Volume down"),
            ("⌘M", "Mute")
        ]),
        Section(title: "Clipboard", entries: [
            ("⌘C", "Copy from device"),
            ("⌘V", "Paste into device")
        ]),
        Section(title: "Window", entries: [
            ("⌘S", "Screenshot"),
            ("⌘⇧R", "Reset video stream"),
            ("⌘⇧P", "Pin window on top"),
            ("⌘⌃F", "Toggle fullscreen"),
            ("⌘/", "Toggle status bar"),
            ("⌘?", "This help overlay"),
            ("Esc", "Close help")
        ])
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "keyboard")
                    Text("Keyboard shortcuts")
                        .font(.title2.bold())
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .top, spacing: 32) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .tracking(0.6)
                            ForEach(section.entries, id: \.0) { entry in
                                HStack(spacing: 10) {
                                    Text(entry.0)
                                        .font(.system(.footnote, design: .monospaced).weight(.medium))
                                        .frame(width: 48, alignment: .leading)
                                        .foregroundColor(.primary)
                                    Text(entry.1)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThickMaterial)
            )
            .frame(maxWidth: 680)
            .shadow(radius: 20)
            .padding(40)
        }
        .transition(.opacity)
    }

    private struct Section: Identifiable {
        let title: String
        let entries: [(String, String)]
        var id: String { title }
    }
}
