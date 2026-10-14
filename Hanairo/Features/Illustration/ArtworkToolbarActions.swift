import SwiftUI

struct ArtworkToolbarActions: ToolbarContent {
    let isBookmarked: Bool
    let isChangingBookmark: Bool
    let isPreparingExport: Bool
    let pageCount: Int
    let shareURL: URL
    let onBookmark: () -> Void
    let onDownloadAll: () -> Void
    let onExportZIP: () -> Void
    let onExportPDF: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: onBookmark) {
                Image(systemName: isBookmarked ? "heart.fill" : "heart")
                    .foregroundStyle(
                        isBookmarked
                            ? AnyShapeStyle(.tint)
                            : AnyShapeStyle(.primary)
                    )
            }
            .disabled(isChangingBookmark)
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark")

            ShareLink(item: shareURL) {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Share artwork")

            downloadControl
        }
    }

    private var downloadControl: some View {
        Menu {
            Button(
                pageCount > 1 ? "Download All \(pageCount) Pages" : "Download Artwork",
                systemImage: "square.and.arrow.down"
            ) {
                onDownloadAll()
            }

            Divider()
            Button("Save as ZIP", systemImage: "doc.zipper") {
                onExportZIP()
            }
            Button("Save as PDF", systemImage: "doc.richtext") {
                onExportPDF()
            }
        } label: {
            if isPreparingExport {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.down.to.line")
            }
        }
        .disabled(isPreparingExport)
        .accessibilityLabel(isPreparingExport ? "Generating export file" : "Download Artwork")
    }
}
