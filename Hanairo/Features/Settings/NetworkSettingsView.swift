import SwiftUI

struct NetworkSettingsView: View {
    @Environment(NetworkSettings.self) private var settings

    @State private var apiState: NetworkDiagnosticState = .idle
    @State private var imageState: NetworkDiagnosticState = .idle
    @State private var showsResetConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("Connection Mode", selection: $settings.mode) {
                    ForEach(AppNetworkMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text(settings.mode.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("Allow Cellular Data", isOn: $settings.allowsCellularAccess)
                Stepper(
                    "Request Timeout: \(settings.requestTimeout) s",
                    value: $settings.requestTimeout,
                    in: NetworkSettings.timeoutRange,
                    step: 5
                )
            } header: {
                Text("Connection")
            } footer: {
                Text("Network settings take effect on the next request. Switching configurations cancels existing connections but doesn't clear caches or your sign-in status.")
            }

            if settings.mode == .httpProxy {
                Section {
                    TextField("Proxy Host", text: $settings.proxyHost)
                    TextField("Proxy Port", value: $settings.proxyPort, format: .number)
                    validationRow(title: "Proxy Configuration", isValid: settings.hasValidProxy)
                } header: {
                    Text("HTTP Proxy")
                } footer: {
                    Text("HTTP and HTTPS requests are sent through the same proxy. Hanairo doesn't bypass TLS certificate validation.")
                }
            }

            Section {
                TextField("API Base URL", text: $settings.apiBaseURLString)
                validationRow(title: "API URL", isValid: settings.hasValidAPIBaseURL)
                TextField("OAuth Base URL", text: $settings.oauthBaseURLString)
                validationRow(title: "OAuth URL", isValid: settings.hasValidOAuthBaseURL)
                TextField("Image Host (Optional)", text: $settings.imageHostOverride)
                validationRow(title: "Image Host", isValid: settings.hasValidImageHost)
            } header: {
                Text("Service URLs")
            } footer: {
                Text("Service URLs must use HTTPS. The image host only replaces i.pximg.net and s.pximg.net and doesn't change image paths. Leave blank to use Pixiv's original address.")
            }

            Section("Connectivity Test") {
                diagnosticRow(title: "Pixiv API", state: apiState) {
                    apiState = .testing
                    apiState = await NetworkDiagnosticsService(settings: settings).testAPI()
                }
                diagnosticRow(title: "Pixiv Images", state: imageState) {
                    imageState = .testing
                    imageState = await NetworkDiagnosticsService(settings: settings).testImage()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Network")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Restore Defaults", systemImage: "arrow.counterclockwise") {
                    showsResetConfirmation = true
                }
                .labelStyle(.iconOnly)
            }
        }
        .confirmationDialog(
            "Restore default network settings?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restore Defaults", role: .destructive) {
                settings.reset()
                apiState = .idle
                imageState = .idle
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func validationRow(title: String, isValid: Bool) -> some View {
        Label(isValid ? "\(title) is valid" : "\(title) is invalid and will fall back to the default", systemImage: isValid ? "checkmark.circle" : "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(isValid ? Color.secondary : Color.red)
    }

    private func diagnosticRow(
        title: String,
        state: NetworkDiagnosticState,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            guard state != .testing else { return }
            Task { await action() }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(state.title)
                        .font(.caption)
                        .foregroundStyle(diagnosticColor(state))
                        .lineLimit(2)
                }
                Spacer()
                if state == .testing {
                    ProgressView()
                } else {
                    Image(systemName: state.systemImage)
                        .foregroundStyle(diagnosticColor(state))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func diagnosticColor(_ state: NetworkDiagnosticState) -> Color {
        switch state {
        case .succeeded: .green
        case .failed: .red
        default: .secondary
        }
    }
}

#Preview("Network Settings") {
    NavigationStack {
        NetworkSettingsView()
    }
    .withPreviewDependencies()
}
