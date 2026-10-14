import SwiftUI

struct LocalBlockSettingsView: View {
    @Environment(LocalBlockStore.self) private var localBlocks

    @State private var showsAddTag = false
    @State private var newTag = ""
    @State private var showsClearConfirmation = false

    var body: some View {
        List {
            if localBlocks.totalCount == 0 {
                ContentUnavailableView(
                    "No Local Blocks",
                    systemImage: "hand.raised",
                    description: Text("You can add blocks from artwork cards, artwork details, comments, or artist profiles.")
                )
            }

            if !localBlocks.tags.isEmpty {
                Section("Tags") {
                    ForEach(localBlocks.tags) { tag in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("#\(tag.displayName)")
                            if tag.translatedName != nil {
                                Text(tag.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { localBlocks.tags[$0].id }
                            .forEach(localBlocks.removeTag(id:))
                    }
                }
            }

            if !localBlocks.users.isEmpty {
                Section("Artists") {
                    ForEach(localBlocks.users) { user in
                        LabeledContent(user.name, value: "ID \(user.id)")
                    }
                    .onDelete { offsets in
                        offsets.map { localBlocks.users[$0].id }
                            .forEach(localBlocks.removeUser(id:))
                    }
                }
            }

            if !localBlocks.artworks.isEmpty {
                Section("Artworks") {
                    ForEach(localBlocks.artworks) { artwork in
                        LabeledContent(artwork.title, value: "ID \(artwork.id)")
                    }
                    .onDelete { offsets in
                        offsets.map { localBlocks.artworks[$0].id }
                            .forEach(localBlocks.removeArtwork(id:))
                    }
                }
            }

            if !localBlocks.comments.isEmpty {
                Section("Comments") {
                    ForEach(localBlocks.comments) { comment in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(comment.authorName)
                                .font(.subheadline.weight(.semibold))
                            Text(comment.preview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { localBlocks.comments[$0].id }
                            .forEach(localBlocks.removeComment(id:))
                    }
                }
            }
        }
        .navigationTitle("Local Blocks")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Add Tag", systemImage: "plus") {
                    newTag = ""
                    showsAddTag = true
                }
                .labelStyle(.iconOnly)

                Button("Clear", systemImage: "trash", role: .destructive) {
                    showsClearConfirmation = true
                }
                .labelStyle(.iconOnly)
                .disabled(localBlocks.totalCount == 0)
            }
        }
        .alert("Add Blocked Tag", isPresented: $showsAddTag) {
            TextField("Tag Name", text: $newTag)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                localBlocks.blockTag(name: newTag)
            }
        }
        .confirmationDialog(
            "Clear all local blocks?",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) { localBlocks.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
