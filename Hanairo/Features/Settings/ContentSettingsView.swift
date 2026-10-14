import SwiftUI

struct ContentSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle("Show AI-Generated Artworks", isOn: $settings.showsAIArtwork)
                Toggle("Show Adult Artworks", isOn: $settings.showsMatureArtwork)
            } footer: {
                Text("Filter settings take effect the next time a list is refreshed. Adult content is off by default.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Content Filtering")
    }
}

#Preview("Content Filtering") {
    NavigationStack {
        ContentSettingsView()
    }
    .withPreviewDependencies()
}
