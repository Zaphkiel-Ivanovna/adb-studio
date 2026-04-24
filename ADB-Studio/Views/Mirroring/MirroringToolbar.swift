import SwiftUI

struct MirroringToolbar: View {
    @ObservedObject var session: MirroringSession
    @Binding var isPinned: Bool
    let onToggleFullscreen: () -> Void
    let onToggleStatusBar: () -> Void
    let onShowShortcuts: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            toolbarButton("chevron.left", help: "Back (⌘B)") { Task { await session.pressBack() } }
            toolbarButton("house", help: "Home (⌘H)") { Task { await session.pressHome() } }
            toolbarButton("square.stack", help: "Recents (⌘⇧A)") { Task { await session.pressRecents() } }

            Divider().frame(height: 16).padding(.horizontal, 4)

            toolbarButton("bell", help: "Notifications (⌘N)") { Task { await session.openNotificationPanel() } }
            toolbarButton("slider.horizontal.3", help: "Quick settings (⌘⇧N)") { Task { await session.openSettingsPanel() } }

            Divider().frame(height: 16).padding(.horizontal, 4)

            toolbarButton("speaker.wave.2", help: "Volume up (⌘↑)") { Task { await session.pressVolume(.up) } }
            toolbarButton("speaker.wave.1", help: "Volume down (⌘↓)") { Task { await session.pressVolume(.down) } }
            toolbarButton("speaker.slash", help: "Mute (⌘M)") { Task { await session.pressVolume(.mute) } }

            Divider().frame(height: 16).padding(.horizontal, 4)

            toolbarButton("rotate.right", help: "Rotate (⌘R)") { Task { await session.rotateDevice() } }
            toolbarButton("lock", help: "Lock device (⌘.)") { Task { await session.pressPower() } }
            toolbarButton("camera", help: "Screenshot (⌘S)") { Task { await session.saveScreenshot() } }
            toolbarButton("arrow.clockwise.circle", help: "Reset stream (⌘⇧R)") { Task { await session.resetVideoStream() } }

            Spacer()

            toolbarButton(isPinned ? "pin.fill" : "pin", help: "Pin on top (⌘⇧P)") { isPinned.toggle() }
            toolbarButton("arrow.up.left.and.arrow.down.right", help: "Fullscreen (⌘⌃F)", action: onToggleFullscreen)
            toolbarButton("minus.rectangle", help: "Toggle status bar (⌘/)", action: onToggleStatusBar)
            toolbarButton("questionmark.circle", help: "Keyboard shortcuts (⌘?)", action: onShowShortcuts)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    private func toolbarButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
