import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    func withAppLaunchExperience(isReady: Bool) -> some View {
        modifier(AppLaunchExperienceModifier(isReady: isReady))
    }
}

private struct AppLaunchExperienceModifier: ViewModifier {
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings

    let isReady: Bool

    @State private var didHandleLaunch = false
    @State private var showsRecommendationDialog = false
    @State private var sharesRecommendationAfterDialogDismissal = false
    @State private var showsRecommendationShareSheet = false
    @State private var didRunAutomaticUpdateCheck = false
    @State private var automaticUpdateAlert: AutomaticUpdateAlert?

    func body(content: Content) -> some View {
        content
            .task(id: isReady) {
                guard isReady else { return }
                await handleLaunch()
            }
            .confirmationDialog(
                "Enjoying Hanairo?",
                isPresented: $showsRecommendationDialog,
                titleVisibility: .visible
            ) {
                Button("Share Hanairo") {
                    shareApplication()
                }
                Button("Not Now") {}
            } message: {
                Text("If Hanairo has been useful to you, consider recommending it to others. Sharing helps more people discover the project.")
            }
            .onChange(of: showsRecommendationDialog) { _, isPresented in
                guard !isPresented else { return }
#if os(iOS)
                if sharesRecommendationAfterDialogDismissal {
                    sharesRecommendationAfterDialogDismissal = false
                    DispatchQueue.main.async {
                        showsRecommendationShareSheet = true
                    }
                    return
                }
#endif
                Task { await checkForUpdatesOnLaunch() }
            }
            .alert(item: $automaticUpdateAlert) { alert in
                Alert(
                    title: Text("New Version Available"),
                    message: Text(
                        "Current version: \(alert.currentVersion). Latest version: \(alert.latestVersion). You can view what's new on the releases page."
                    ),
                    primaryButton: .default(Text("Open Releases Page")) {
                        openURL(alert.releaseURL)
                    },
                    secondaryButton: .cancel(Text("Later"))
                )
            }
#if os(iOS)
            .sheet(isPresented: $showsRecommendationShareSheet, onDismiss: {
                Task { await checkForUpdatesOnLaunch() }
            }) {
                ApplicationRecommendationShareSheet(
                    activityItems: ["I'm using Hanairo — you should try it too!", AppUpdateService.repositoryURL]
                )
            }
#endif
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    @MainActor
    private func handleLaunch() async {
        guard !didHandleLaunch else { return }
        didHandleLaunch = true

        if AppRecommendationPrompt.recordLaunch() {
            showsRecommendationDialog = true
        } else {
            await checkForUpdatesOnLaunch()
        }
    }

    private func shareApplication() {
#if os(iOS)
        sharesRecommendationAfterDialogDismissal = true
#else
        openURL(AppUpdateService.repositoryURL)
#endif
    }

    @MainActor
    private func checkForUpdatesOnLaunch() async {
        guard settings.checksUpdatesOnLaunch, !didRunAutomaticUpdateCheck else { return }
        didRunAutomaticUpdateCheck = true

        do {
            let result = try await AppUpdateService.checkLatestRelease(currentVersion: appVersion)
            guard result.hasUpdate else { return }

            automaticUpdateAlert = AutomaticUpdateAlert(
                currentVersion: result.currentVersion,
                latestVersion: result.latestVersion,
                releaseURL: result.releaseURL
            )
        } catch {
            // Don't interrupt launch if the automatic check fails.
        }
    }

    private struct AutomaticUpdateAlert: Identifiable {
        let id = UUID()
        let currentVersion: String
        let latestVersion: String
        let releaseURL: URL
    }
}

#if os(iOS)
private struct ApplicationRecommendationShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
