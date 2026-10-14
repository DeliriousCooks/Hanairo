import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Interface & Content") {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label("Appearance & Images", systemImage: "paintbrush")
                }

                NavigationLink {
                    ContentSettingsView()
                } label: {
                    Label("Content Filtering", systemImage: "line.3.horizontal.decrease.circle")
                }
            }

            Section("Pixiv Interaction") {
                NavigationLink {
                    InteractionSettingsView()
                } label: {
                    Label("Bookmarks & Following", systemImage: "heart.text.square")
                }
            }

            Section("Connection") {
                NavigationLink {
                    NetworkSettingsView()
                } label: {
                    Label("Network", systemImage: "network")
                }
            }

            Section("Files & Storage") {
                NavigationLink {
                    DownloadSettingsView()
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }

                NavigationLink {
                    CacheSettingsView()
                } label: {
                    Label("Cache", systemImage: "internaldrive")
                }
            }

            Section("Privacy & Local Data") {
                NavigationLink(value: AppRoute.localDataSettings) {
                    Label("History & Blocks", systemImage: "hand.raised")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
    }
    .withPreviewDependencies()
}
