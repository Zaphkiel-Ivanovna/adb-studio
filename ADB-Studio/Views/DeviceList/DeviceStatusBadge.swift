import SwiftUI

struct DeviceStatusBadge: View {
    let state: DeviceState

    private var backgroundColor: Color {
        switch state {
        case .device:
            return .green
        case .unauthorized:
            return .orange
        case .offline:
            return .red
        case .connecting:
            return .blue
        case .unknown:
            return .gray
        }
    }

    var body: some View {
        Text(state.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .cornerRadius(4)
    }
}

#Preview {
    VStack(spacing: 8) {
        DeviceStatusBadge(state: .device)
        DeviceStatusBadge(state: .unauthorized)
        DeviceStatusBadge(state: .offline)
        DeviceStatusBadge(state: .connecting)
        DeviceStatusBadge(state: .unknown)
    }
    .padding()
}
