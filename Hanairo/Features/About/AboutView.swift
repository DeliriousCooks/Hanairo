import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings

    @State private var isCheckingUpdate = false
    @State private var updateAlert: UpdateAlert?

    var body: some View {
        @Bindable var settings = settings

        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(Color.accentColor.gradient)
                    Text("Hanairo")
                        .font(.title.weight(.bold))
                    Text("Version \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }

            Section {
                Button {
                    Task {
                        await checkForUpdates()
                    }
                } label: {
                    HStack {
                        Label(
                            isCheckingUpdate ? "Checking for Updates" : "Check for Updates",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        Spacer()
                        if isCheckingUpdate {
                            ProgressView()
                        }
                    }
                }
                .disabled(isCheckingUpdate)

                Toggle("Check for Updates on Launch", isOn: $settings.checksUpdatesOnLaunch)
            } header: {
                Text("Updates")
            } footer: {
                Text("Automatic checks only notify you when a new version is found. A failed check won't interrupt launch.")
            }

            Section("About This App") {
                Text("Hanairo is a third-party Pixiv client built with SwiftUI and system frameworks.")
                Text("Pixiv, pixiv, and related logos are property of pixiv Inc.")
            }

            Section("Open Source License") {
                Text("Hanairo is released under the Mozilla Public License 2.0 (MPL-2.0).")
                Link(destination: AppUpdateService.repositoryURL) {
                    Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://www.mozilla.org/MPL/2.0/")!) {
                    Label("View MPL 2.0", systemImage: "doc.text")
                }
            }

            Section("Community") {
                Link(destination: URL(string: "https://t.me/hanairo_official")!) {
                    HStack {
                        Label("Telegram Group", systemImage: "paperplane")
                        Spacer()
                        Text("@hanairo_official")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Acknowledgements") {
                Text("Feature structure was inspired by the PixEz Flutter project.")
                Link(destination: URL(string: "https://github.com/Notsfsssf/pixez-flutter")!) {
                    Label("PixEz Flutter", systemImage: "arrow.up.right.square")
                }
            }
        }
        .navigationTitle("About")
        .alert(item: $updateAlert) { alert in
            if let releaseURL = alert.releaseURL {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Open Releases Page")) {
                        openURL(releaseURL)
                    },
                    secondaryButton: .cancel(Text("OK"))
                )
            } else {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    @MainActor
    private func checkForUpdates() async {
        guard !isCheckingUpdate else { return }

        isCheckingUpdate = true
        defer { isCheckingUpdate = false }

        do {
            let result = try await AppUpdateService.checkLatestRelease(currentVersion: version)
            if result.hasUpdate {
                updateAlert = UpdateAlert(
                    title: "New Version Available",
                    message: "Current version: \(result.currentVersion). Latest version: \(result.latestVersion). You can view what's new on the releases page.",
                    releaseURL: result.releaseURL
                )
            } else {
                updateAlert = UpdateAlert(
                    title: "You're Up to Date",
                    message: "Version \(result.currentVersion) is the latest version.",
                    releaseURL: nil
                )
            }
        } catch {
            updateAlert = UpdateAlert(
                title: "Update Check Failed",
                message: error.localizedDescription,
                releaseURL: nil
            )
        }
    }

    private struct UpdateAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let releaseURL: URL?
    }
}
