import SwiftUI

struct PortForwardSettingsTab: View {
    @ObservedObject var viewModel: PortForwardSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.devices.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.devices) { device in
                    DeviceSettingsCard(device: device, viewModel: viewModel)
                }
            }
        }
        .padding(24)
        .onAppear { viewModel.reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("No saved presets yet")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Open a connected device, add a port forward, and tick \"Save as preset\".")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

private struct DeviceSettingsCard: View {
    let device: DeviceHistory
    @ObservedObject var viewModel: PortForwardSettingsViewModel

    @State private var showRemoveConfirmation = false

    var body: some View {
        SettingsSection(title: device.displayLabel.uppercased()) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(device.portForwardPresets) { preset in
                    PortForwardPresetRowView(
                        preset: preset,
                        showApplyButton: false,
                        isApplying: false,
                        onToggleAutoApply: { viewModel.toggleAutoApply(preset, for: device.persistentSerial) },
                        onApply: nil,
                        onRename: { name in viewModel.rename(preset, to: name, for: device.persistentSerial) },
                        onDelete: { viewModel.removePreset(preset, for: device.persistentSerial) }
                    )
                }

                HStack {
                    Spacer()
                    Button(role: .destructive, action: {
                        showRemoveConfirmation = true
                    }) {
                        Label("Forget all presets", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }
        }
        .alert("Forget all presets for this device?",
               isPresented: $showRemoveConfirmation) {
            Button("Forget", role: .destructive) {
                viewModel.clearPresets(for: device.persistentSerial)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes all saved port forward presets for \(device.displayLabel).")
        }
    }
}
