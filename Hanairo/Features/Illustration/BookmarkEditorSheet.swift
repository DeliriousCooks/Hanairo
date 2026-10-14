import SwiftUI

struct BookmarkEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PixivRepository.self) private var repository

    let illustration: PixivIllustration
    let onSaved: (Bool) -> Void

    @State private var phase: LoadState<PixivBookmarkDetail> = .idle
    @State private var visibility: PixivVisibility = .public
    @State private var tags: [PixivBookmarkDetailTag] = []
    @State private var selectedTags = Set<String>()
    @State private var newTag = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Edit Bookmark")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(!isLoaded || isSaving)
                    }
                }
        }
        .interactiveDismissDisabled(isSaving)
        .task(id: illustration.id) {
            await load()
        }
        .alert("Action Failed", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle, .loading:
            ProgressView("Loading bookmark info…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await load() }
            }
        case let .loaded(detail):
            Form {
                Section("Visibility") {
                    Picker("Bookmark Visibility", selection: $visibility) {
                        ForEach(PixivVisibility.allCases) { visibility in
                            Text(visibility.title).tag(visibility)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        TextField("New Tag", text: $newTag)
                            .submitLabel(.done)
                            .onSubmit(addTag)
                        Button("Add", action: addTag)
                            .disabled(normalizedNewTag.isEmpty)
                    }
                } header: {
                    HStack {
                        Text("Tags")
                        Spacer()
                        Button(selectedTags.count == tags.count ? "Deselect All" : "Select All") {
                            toggleAllTags()
                        }
                        .textCase(nil)
                    }
                }

                Section {
                    if tags.isEmpty {
                        ContentUnavailableView("No Tags", systemImage: "tag")
                    } else {
                        ForEach(tags, id: \.name) { tag in
                            Button {
                                toggleTag(tag.name)
                            } label: {
                                HStack {
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTags.contains(tag.name) {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } footer: {
                    Text("\(selectedTags.count) tags selected")
                }

                if detail.isBookmarked {
                    Section {
                        Button("Remove Bookmark", role: .destructive) {
                            removeBookmark()
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
    }

    private var isLoaded: Bool {
        if case .loaded = phase { return true }
        return false
    }

    private var normalizedNewTag: String {
        newTag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func load() async {
        phase = .loading
        do {
            let detail = try await repository.bookmarkDetail(id: illustration.id)
            guard !Task.isCancelled else { return }
            visibility = detail.visibility
            tags = uniqueTags(detail.tags)
            selectedTags = Set(detail.tags.filter(\.isRegistered).map(\.name))
            phase = .loaded(detail)
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func addTag() {
        let value = normalizedNewTag
        guard !value.isEmpty else { return }
        if !tags.contains(where: { $0.name == value }) {
            tags.insert(PixivBookmarkDetailTag(name: value, isRegistered: true), at: 0)
        }
        selectedTags.insert(value)
        newTag = ""
    }

    private func toggleTag(_ name: String) {
        if selectedTags.contains(name) {
            selectedTags.remove(name)
        } else {
            selectedTags.insert(name)
        }
    }

    private func toggleAllTags() {
        if selectedTags.count == tags.count {
            selectedTags.removeAll()
        } else {
            selectedTags = Set(tags.map(\.name))
        }
    }

    private func save() {
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                try await repository.updateBookmark(
                    id: illustration.id,
                    visibility: visibility,
                    tags: selectedTags.sorted()
                )
                onSaved(true)
                dismiss()
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func removeBookmark() {
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                try await repository.removeBookmark(id: illustration.id)
                onSaved(false)
                dismiss()
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func uniqueTags(_ values: [PixivBookmarkDetailTag]) -> [PixivBookmarkDetailTag] {
        var names = Set<String>()
        return values.filter { names.insert($0.name).inserted }
    }
}
