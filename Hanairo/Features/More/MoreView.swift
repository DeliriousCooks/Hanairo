import SwiftUI

struct MoreView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @State private var showsSignOutConfirmation = false

    var body: some View {
        List {
            accountSection

            Section("Pixiv") {
                NavigationLink(value: AppRoute.mangaWatchlist) {
                    Label("Manga Watchlist", systemImage: "books.vertical")
                }
                NavigationLink(value: AppRoute.downloads) {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
                NavigationLink(value: AppRoute.browsingHistory) {
                    Label("Browsing History", systemImage: "clock.arrow.circlepath")
                }
            }

            Section("Hanairo") {
                NavigationLink(value: AppRoute.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
                NavigationLink(value: AppRoute.about) {
                    Label("About", systemImage: "info.circle")
                }
            }

            Section("Links") {
                Link(destination: URL(string: "https://www.pixiv.net")!) {
                    Label("Open Pixiv", systemImage: "arrow.up.right.square")
                }
            }

            Section {
                Text("Hanairo is an unofficial Pixiv client and is not affiliated with pixiv Inc.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Me")
        .confirmationDialog(
            "Sign out of this account?",
            isPresented: $showsSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                authentication.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Pixiv token in this device's Keychain will be deleted.")
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        Section("Account") {
            if let account = authentication.account, let id = account.numericID {
                let preview = PixivUser(
                    id: id,
                    name: account.name,
                    account: account.account,
                    profileImageURLs: .init(
                        medium: account.profileImageURLs.large
                            ?? account.profileImageURLs.medium
                    )
                )

                NavigationLink(value: AppRoute.user(id: id, preview: preview)) {
                    HStack(spacing: 12) {
                        RemoteImageView(
                            url: account.profileImageURLs.large ?? account.profileImageURLs.medium
                        )
                        .frame(width: 54, height: 54)
                        .clipShape(Circle())
                        .clipped()
                        VStack(alignment: .leading, spacing: 3) {
                            Text(account.name)
                                .font(.headline)
                            Text("@\(account.account)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .appNavigationTransitionSource(for: .user(id: id))
                }
                Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    showsSignOutConfirmation = true
                }
            }
        }
    }
}

#Preview("Me") {
    NavigationStack {
        MoreView()
    }
    .withPreviewDependencies()
}
