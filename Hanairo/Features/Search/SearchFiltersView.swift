import SwiftUI

struct SearchFiltersView: View {
    @Environment(\.dismiss) private var dismiss

    let isPremium: Bool
    let onApply: (PixivSearchOptions) -> Void

    @State private var draft: PixivSearchOptions

    init(
        options: PixivSearchOptions,
        isPremium: Bool,
        onApply: @escaping (PixivSearchOptions) -> Void
    ) {
        _draft = State(initialValue: options)
        self.isPremium = isPremium
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Match") {
                    Picker("Search In", selection: $draft.target) {
                        ForEach(PixivSearchTarget.allCases) { target in
                            Text(target.title).tag(target)
                        }
                    }
                    Picker("Artwork Type", selection: $draft.mediaFilter) {
                        ForEach(PixivSearchMediaFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    Picker("AI Artworks", selection: $draft.aiFilter) {
                        ForEach(PixivSearchAIFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                }

                Section {
                    Picker("Sort By", selection: $draft.sort) {
                        ForEach(availableSorts) { sort in
                            Text(sortTitle(sort)).tag(sort)
                        }
                    }
                    Picker("Bookmarks", selection: $draft.bookmarkThreshold) {
                        ForEach(PixivBookmarkThreshold.allCases) { threshold in
                            Text(threshold.title).tag(threshold)
                        }
                    }
                } header: {
                    Text("Sorting & Popularity")
                } footer: {
                    if !isPremium {
                        Text("Without Premium, Most Popular uses Pixiv's popular preview results. Sorting by user gender is available to Premium members only.")
                    }
                }

                Section("Publish Date") {
                    Toggle("Limit Date Range", isOn: $draft.usesDateRange)
                    if draft.usesDateRange {
                        DatePicker(
                            "Start Date",
                            selection: $draft.startDate,
                            in: ...draft.endDate,
                            displayedComponents: .date
                        )
                        DatePicker(
                            "End Date",
                            selection: $draft.endDate,
                            in: draft.startDate...Date(),
                            displayedComponents: .date
                        )
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { draft = PixivSearchOptions() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var availableSorts: [PixivSearchSort] {
        if isPremium {
            return PixivSearchSort.allCases
        }
        return [.newest, .oldest, .popular]
    }

    private func sortTitle(_ sort: PixivSearchSort) -> String {
        if !isPremium, sort == .popular {
            return "Popular Preview"
        }
        return sort.title
    }
}
