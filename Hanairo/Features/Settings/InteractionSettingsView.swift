import SwiftUI

struct InteractionSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("Default Bookmark Visibility", selection: $settings.defaultBookmarkVisibility) {
                    ForEach(PixivVisibility.allCases) { visibility in
                        Text(visibility.title).tag(visibility)
                    }
                }

                Picker("Default Follow Visibility", selection: $settings.defaultFollowVisibility) {
                    ForEach(PixivVisibility.allCases) { visibility in
                        Text(visibility.title).tag(visibility)
                    }
                }
            } header: {
                Text("Default Visibility")
            } footer: {
                Text("Used for quick bookmarks and follows. You can still change it individually on artwork and artist pages.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Bookmarks & Following")
    }
}

#Preview("Bookmark & Follow Settings") {
    NavigationStack {
        InteractionSettingsView()
    }
    .withPreviewDependencies()
}
