import SwiftUI

struct PortForwardPresetsSection: View {
    @ObservedObject var viewModel: DeviceDetailViewModel

    @State private var applyingPresetId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved Presets")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.presets.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Capsule())
            }

            if !viewModel.canPersistPresets {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("Connect this device once via USB so it gets a persistent serial — needed to save presets.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.presets.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "bookmark")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No saved presets yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Tick \"Save as preset\" when adding a port forward.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.presets) { preset in
                        PortForwardPresetRowView(
                            preset: preset,
                            showApplyButton: true,
                            isApplying: applyingPresetId == preset.id,
                            onToggleAutoApply: { viewModel.togglePresetAutoApply(preset) },
                            onApply: {
                                applyingPresetId = preset.id
                                Task {
                                    await viewModel.applyPreset(preset)
                                    applyingPresetId = nil
                                }
                            },
                            onRename: { name in viewModel.renamePreset(preset, to: name) },
                            onDelete: { viewModel.removePreset(preset) }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
