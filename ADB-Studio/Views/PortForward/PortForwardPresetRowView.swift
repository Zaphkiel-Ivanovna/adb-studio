import SwiftUI

struct PortForwardPresetRowView: View {
    let preset: PortForwardPreset
    let showApplyButton: Bool
    let isApplying: Bool
    let onToggleAutoApply: () -> Void
    let onApply: (() -> Void)?
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var isEditingName = false
    @State private var draftName = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            // leading icon (bookmark / bolt) with a11y label
            Image(systemName: preset.autoApply ? "bolt.fill" : "bookmark")
                .foregroundColor(preset.autoApply ? .accentColor : .secondary)
                .frame(width: 18)
                .accessibilityLabel(preset.autoApply ? "Auto-apply enabled" : "Saved preset")

            // name + command description (or rename editor when isEditingName)
            VStack(alignment: .leading, spacing: 2) {
                if isEditingName {
                    HStack(spacing: 6) {
                        TextField("Name", text: $draftName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { commitName() }
                        Button(action: commitName) { Image(systemName: "checkmark") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Confirm name")
                            .help("Confirm")
                        Button(action: { isEditingName = false }) { Image(systemName: "xmark") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Cancel rename")
                            .help("Cancel")
                    }
                } else {
                    Text(preset.displayName).font(.subheadline)
                }
                Text(preset.commandDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            // Auto-apply toggle (compact switch, labeled for VoiceOver)
            Toggle("", isOn: Binding(
                get: { preset.autoApply },
                set: { _ in onToggleAutoApply() }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .accessibilityLabel("Auto-apply on connect for \(preset.displayName)")
            .help("Auto-apply when this device connects")

            // Apply Now (only Network tab)
            if showApplyButton, let onApply = onApply {
                Button(action: onApply) {
                    if isApplying {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isApplying)
                .accessibilityLabel("Apply preset \(preset.displayName) now")
                .help("Apply now")
            }

            Button(action: startEditing) { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .accessibilityLabel("Rename preset \(preset.displayName)")
                .help("Rename")

            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete preset \(preset.displayName)")
            .help("Delete")
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .disabled(isApplying)
        .confirmationDialog(
            "Delete \"\(preset.displayName)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved preset. The active port forward (if any) is not affected.")
        }
    }

    private func startEditing() {
        draftName = preset.name ?? ""
        isEditingName = true
    }

    private func commitName() {
        onRename(draftName)
        isEditingName = false
    }
}
