import SwiftUI

struct TokenLoginView: View {
    @Environment(AuthenticationStore.self) private var authentication

    @State private var refreshToken = ""
    @State private var revealsToken = false
    @FocusState private var isTokenFieldFocused: Bool

    var body: some View {
        Form {
            tokenSection

            if let errorMessage = authentication.errorMessage {
                Section {
                    AuthenticationErrorView(message: errorMessage)
                }
            }

            submitSection
        }
        .formStyle(.grouped)
        .navigationTitle("Token Sign-In")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                PasteButton(payloadType: String.self) { values in
                    guard let value = values.first else { return }
                    refreshToken = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .accessibilityLabel("Paste Token")
                .help("Paste Token")
            }
        }
        .onAppear {
            authentication.clearError()
            isTokenFieldFocused = true
        }
    }

    private var tokenSection: some View {
        Section {
            Group {
                if revealsToken {
                    TextField("Paste Refresh Token", text: $refreshToken)
                } else {
                    SecureField("Paste Refresh Token", text: $refreshToken)
                }
            }
            .focused($isTokenFieldFocused)
            .onSubmit {
                guard canSubmit else { return }
                Task { await signIn() }
            }

            Toggle("Show Token", isOn: $revealsToken)

            if !normalizedToken.isEmpty {
                LabeledContent("Character Count", value: normalizedToken.count.formatted())
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Refresh Token")
        } footer: {
            Text("The token is stored only in the system Keychain. Don't share it with anyone.")
        }
    }

    private var submitSection: some View {
        Section {
            Button {
                Task { await signIn() }
            } label: {
                HStack {
                    Spacer()
                    if authentication.isAuthenticating {
                        ProgressView()
                        Text("Verifying…")
                    } else {
                        Label("Sign In", systemImage: "arrow.right.circle.fill")
                    }
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canSubmit)
        }
    }

    private var normalizedToken: String {
        refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !normalizedToken.isEmpty && !authentication.isAuthenticating
    }

    private func signIn() async {
        guard canSubmit else { return }
        isTokenFieldFocused = false
        do {
            try await authentication.signIn(refreshToken: normalizedToken)
        } catch {
            return
        }
    }
}

#Preview("Token Sign-In") {
    NavigationStack {
        TokenLoginView()
    }
    .withPreviewDependencies()
}
