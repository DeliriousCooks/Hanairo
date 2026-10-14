import SwiftUI

struct LocalDataSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(BrowsingHistoryStore.self) private var history
    @Environment(LocalBlockStore.self) private var localBlocks

    @State private var showsClearHistoryConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle("Record Browsing History", isOn: $settings.recordsBrowsingHistory)
                Stepper(
                    "Keep up to \(settings.browsingHistoryLimit) entries",
                    value: $settings.browsingHistoryLimit,
                    in: AppSettings.browsingHistoryLimitRange,
                    step: 50
                )
                .onChange(of: settings.browsingHistoryLimit) {
                    history.applyCurrentLimit()
                }
                NavigationLink(value: AppRoute.browsingHistory) {
                    LabeledContent("Manage Browsing History", value: "\(history.entries.count)")
                }
                Button("Clear Browsing History", systemImage: "trash", role: .destructive) {
                    showsClearHistoryConfirmation = true
                }
                .disabled(history.entries.isEmpty)
            } header: {
                Text("Browsing History")
            } footer: {
                Text("History is stored only on this device and isn't synced to Pixiv. Turning off recording doesn't delete existing history.")
            }

            Section {
                NavigationLink {
                    LocalBlockSettingsView()
                } label: {
                    LabeledContent("Manage Blocked Content", value: "\(localBlocks.totalCount)")
                }
            } header: {
                Text("Local Blocks")
            } footer: {
                Text("Local blocks don't change your Pixiv account. They only affect which artworks and artists are shown in Hanairo.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("History & Blocks")
        .confirmationDialog(
            "Clear all browsing history?",
            isPresented: $showsClearHistoryConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) { history.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
