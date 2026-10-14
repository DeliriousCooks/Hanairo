import SwiftUI

struct ErrorStateView: View {
    let message: String
    var usesGlassButton = false
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Failed to Load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            retryButton
        }
    }

    @ViewBuilder
    private var retryButton: some View {
#if os(visionOS)
        fallbackRetryButton
#else
        if #available(iOS 26.0, macOS 26.0, *), usesGlassButton {
            Button("Retry", action: retry)
                .buttonStyle(.glassProminent)
        } else {
            fallbackRetryButton
        }
#endif
    }

    private var fallbackRetryButton: some View {
        Button("Retry", action: retry)
            .buttonStyle(.borderedProminent)
    }
}
