import SwiftUI

struct DownloadSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ArtworkDownloadManager.self) private var downloadManager

    @State private var storageUsage: ArtworkDownloadStorageUsage?

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("Default Save Location", selection: $settings.downloadDestination) {
                    ForEach(ArtworkDownloadDestination.allCases) { destination in
                        Text(destination.title).tag(destination)
                    }
                }
            } header: {
                Text("Save Location")
            } footer: {
                Text("The photo library saves each page as soon as it finishes. Files are saved to Hanairo Downloads in the Files app and can be exported page by page from the download details.")
            }

            Section {
                Stepper(
                    value: $settings.downloadConcurrentTaskCount,
                    in: AppSettings.downloadConcurrentTaskRange
                ) {
                    LabeledContent("Concurrent Tasks", value: "\(settings.downloadConcurrentTaskCount)")
                }

                Stepper(
                    value: $settings.downloadRetryCount,
                    in: AppSettings.downloadRetryRange
                ) {
                    LabeledContent("Retries on Failure", value: "\(settings.downloadRetryCount) times")
                }

                Toggle("Prefer Image Cache", isOn: $settings.downloadReadsImageCache)
                Toggle("Bookmark on Download", isOn: $settings.bookmarksOnDownload)
            } header: {
                Text("Tasks")
            } footer: {
                Text("Auto-bookmark uses the default bookmark visibility. Running tasks pause after the current page finishes. After the app restarts, unfinished tasks return to the waiting state.")
            }

            Section("Download Management") {
                LabeledContent("Download Records", value: "\(downloadManager.records.count)")
                if let storageUsage {
                    LabeledContent(
                        "Local Storage Used",
                        value: ByteCountFormatter.string(
                            fromByteCount: storageUsage.totalBytes,
                            countStyle: .file
                        )
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Downloads")
        .task(id: usageRequestKey) {
            storageUsage = await downloadManager.storageUsage()
        }
    }

    private var usageRequestKey: String {
        "\(downloadManager.tasks.count)-\(downloadManager.records.count)"
    }
}

#Preview("Downloads") {
    NavigationStack {
        DownloadSettingsView()
    }
    .withPreviewDependencies()
}
