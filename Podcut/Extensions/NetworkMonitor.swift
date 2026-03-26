import Network
import SwiftUI

/// Observable network connectivity monitor.
@MainActor @Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    var isConnected: Bool = true
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }
}

/// A reusable offline banner view.
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.subheadline)
            Text("No internet connection")
                .font(.subheadline.weight(.medium))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.red.gradient, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// A retry button for failed network requests.
struct RetryView: View {
    let message: String
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Connection Error", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .buttonBorderShape(.capsule)
        }
    }
}
