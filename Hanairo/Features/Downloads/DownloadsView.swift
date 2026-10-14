import SwiftUI

struct DownloadsView: View {
    @Environment(ArtworkDownloadManager.self) private var downloadManager

    @State private var section: DownloadsSection = .queue
    @State private var showsClearConfirmation = false

    var body: some View {
        List {
            Picker("Downloads Section", selection: $section) {
                ForEach(DownloadsSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            switch section {
            case .queue:
                queueContent
            case .completed:
                completedContent
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Downloads")
        .toolbar {
            if hasContent {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showsClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(section == .queue ? "Clear Download Queue" : "Clear Download History")
                }
            }
        }
        .alert(clearTitle, isPresented: $showsClearConfirmation) {
            Button("Clear", role: .destructive, action: clear)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(clearMessage)
        }
    }

    @ViewBuilder
    private var queueContent: some View {
        if downloadManager.tasks.isEmpty {
            ContentUnavailableView(
                "No Download Tasks",
                systemImage: "tray",
                description: Text("Artworks are added to the download queue from their detail page.")
            )
            .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(downloadManager.tasks) { task in
                    ArtworkDownloadTaskRow(task: task)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if task.status == .paused {
                                Button {
                                    downloadManager.resume(task)
                                } label: {
                                    Label("Resume", systemImage: "play.fill")
                                }
                                .tint(.green)
                            } else if task.status == .queued || task.status == .downloading {
                                Button {
                                    downloadManager.pause(task)
                                } label: {
                                    Label("Pause", systemImage: "pause.fill")
                                }
                                .tint(.orange)
                            }

                            Button {
                                downloadManager.prioritize(task)
                            } label: {
                                Label("Prioritize", systemImage: "arrow.up.to.line")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                downloadManager.removeTask(task)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            if task.status == .failed {
                                Button {
                                    downloadManager.retry(task)
                                } label: {
                                    Label("Retry", systemImage: "arrow.clockwise")
                                }
                                .tint(.blue)
                            }
                        }
                }
            } footer: {
                Text("Swipe right to pause, resume, or prioritize. Swipe left to remove. Failed tasks can be retried.")
            }
        }
    }

    @ViewBuilder
    private var completedContent: some View {
        if downloadManager.records.isEmpty {
            ContentUnavailableView(
                "No Download History",
                systemImage: "checkmark.circle",
                description: Text("Successfully saved images appear here.")
            )
            .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(downloadManager.records) { record in
                    NavigationLink(value: AppRoute.downloadRecord(id: record.id)) {
                        ArtworkDownloadRecordRow(record: record)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            downloadManager.removeRecord(record)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text("Deleting a file record also deletes the corresponding local images in Hanairo Downloads. Images in the photo library are not deleted.")
            }
        }
    }

    private var hasContent: Bool {
        section == .queue ? !downloadManager.tasks.isEmpty : !downloadManager.records.isEmpty
    }

    private var clearTitle: String {
        section == .queue ? "Clear download queue?" : "Clear download history?"
    }

    private var clearMessage: String {
        section == .queue
            ? "All waiting, downloading, paused, and failed tasks will be removed. Completed files won't be deleted."
            : "File records and local images in Hanairo Downloads will be deleted. Images in the photo library won't be deleted."
    }

    private func clear() {
        switch section {
        case .queue: downloadManager.clearTasks()
        case .completed: downloadManager.clearRecords()
        }
    }
}

private enum DownloadsSection: String, CaseIterable, Identifiable {
    case queue
    case completed

    var id: String { rawValue }
    var title: String { self == .queue ? "Queue" : "Completed" }
}

#Preview("Downloads") {
    NavigationStack {
        DownloadsView()
    }
    .withPreviewDependencies()
}
