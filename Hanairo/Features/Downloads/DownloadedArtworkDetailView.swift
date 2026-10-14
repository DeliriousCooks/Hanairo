import SwiftUI

struct DownloadedArtworkDetailView: View {
    @Environment(ArtworkDownloadManager.self) private var downloadManager

    let recordID: String

    @State private var viewer: DownloadedPageViewerContext?

    var body: some View {
        Group {
            if let record {
                recordContent(record)
            } else {
                ContentUnavailableView("Download Record Not Found", systemImage: "questionmark.folder")
            }
        }
        .navigationTitle("Download Details")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $viewer) { context in
            DownloadedPageViewer(context: context)
        }
    }

    private func recordContent(_ record: ArtworkDownloadRecord) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.title)
                        .font(.title2.weight(.bold))
                        .textSelection(.enabled)
                    Text(record.artistName)
                        .foregroundStyle(.secondary)
                    Label(record.detailText, systemImage: record.isComplete ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(record.isComplete ? .green : .orange)
                }

                if record.destination == .photoLibrary {
                    ContentUnavailableView(
                        "Images Saved to Photo Library",
                        systemImage: "photo.on.rectangle",
                        description: Text("Hanairo only keeps the download record and won't save photo library images again.")
                    )
                    .frame(minHeight: 260)
                } else {
                    ForEach(record.pages) { page in
                        if let url = downloadManager.localURL(for: record, page: page) {
                            VStack(alignment: .trailing, spacing: 8) {
                                Button {
                                    viewer = DownloadedPageViewerContext(
                                        pageIndex: page.pageIndex,
                                        url: url
                                    )
                                } label: {
                                    LocalImageView(url: url, contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 480)
                                        .background(.black.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .clipped()
                                }
                                .buttonStyle(.plain)

                                ShareLink(item: url) {
                                    Label("Export Page \(page.pageIndex + 1)", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            Color.gray.opacity(0.28)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    Text("File for page \(page.pageIndex + 1) not found")
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                }

                NavigationLink(value: AppRoute.illustration(id: record.illustrationID)) {
                    Label("View Artwork Online", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .padding(.bottom, 20)
        }
    }

    private var record: ArtworkDownloadRecord? {
        downloadManager.records.first { $0.id == recordID }
    }
}

private struct DownloadedPageViewerContext: Identifiable {
    let pageIndex: Int
    let url: URL

    var id: String { "\(pageIndex)-\(url.path)" }
}

private struct DownloadedPageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let context: DownloadedPageViewerContext

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ZoomableMediaView {
                LocalImageView(url: context.url, contentMode: .fit)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.leading, 14)
            .accessibilityLabel("Close")
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}
