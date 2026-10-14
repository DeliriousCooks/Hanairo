import SwiftUI

struct ArtworkInformationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let illustration: PixivIllustration

    var body: some View {
        NavigationStack {
            Form {
                Section("Artwork") {
                    LabeledContent("Title", value: illustration.title)
                    LabeledContent("Artwork ID", value: String(illustration.id))
                    LabeledContent("Artist", value: illustration.user.name)
                    LabeledContent("Artist ID", value: String(illustration.user.id))
                    LabeledContent("Pages", value: String(illustration.pageCount))
                    LabeledContent("Size", value: "\(illustration.width) × \(illustration.height)")
                    if !illustration.createDate.isEmpty {
                        LabeledContent("Publish Date", value: String(illustration.createDate.prefix(10)))
                    }
                }

                if !illustration.tags.isEmpty {
                    Section("Tags") {
                        Text(illustration.tags.map { "#\($0.displayName)" }.joined(separator: "  "))
                            .textSelection(.enabled)
                    }
                }

                let caption = TextSanitizer.plainText(from: illustration.caption)
                if !caption.isEmpty {
                    Section("Caption") {
                        Text(caption)
                            .textSelection(.enabled)
                    }
                }

                Section("Share") {
                    ShareLink(item: shareText) {
                        Label("Share Artwork Info", systemImage: "doc.text")
                    }
                    ShareLink(item: PixivWebLinks.artwork(id: illustration.id)) {
                        Label("Share Artwork Link", systemImage: "link")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Artwork Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var shareText: String {
        [
            "Title: \(illustration.title)",
            "Artist: \(illustration.user.name)",
            "Artwork ID: \(illustration.id)",
            PixivWebLinks.artwork(id: illustration.id).absoluteString
        ].joined(separator: "\n")
    }
}
