import SwiftUI
#if os(iOS)
import UIKit
#endif

struct UserDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks
    @Environment(AppSettings.self) private var settings
    @Environment(AppTheme.self) private var theme

    let userID: Int
    let initialUser: PixivUser?

    @State private var detailState: LoadState<PixivUserDetail> = .idle
    @State private var completedDetailRequestKey: String?
    @State private var selectedSection: AuthorArtworkSection = .illustrations
    @State private var artworks = PaginatedStore<PixivIllustration>(id: { $0.id })
    @State private var actionError: String?
    @State private var showsBlockConfirmation = false
    @State private var profileAccentColor: Color?

    init(userID: Int, initialUser: PixivUser? = nil) {
        self.userID = userID
        self.initialUser = initialUser
    }

    var body: some View {
        ZStack {
            switch detailState {
            case .idle, .loading:
                loadingContent(initialUser)
                    .transition(.opacity)
            case let .failed(message):
                ErrorStateView(message: message, usesGlassButton: true) {
                    Task { await retryDetail() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.055))
                .transition(.opacity)
            case let .loaded(detail):
                userContent(detail)
                    .transition(.opacity)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .tint(profileAccentColor ?? theme.accentColor)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: PixivWebLinks.user(id: userID)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share artist profile")
            }

            if
                case let .loaded(detail) = detailState,
                authentication.userID != detail.user.id
            {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(
                            "Block Artist",
                            systemImage: "person.crop.circle.badge.minus",
                            role: .destructive
                        ) {
                            showsBlockConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More actions")
                }
            }
        }
        .task(id: detailRequestKey) {
            await loadDetailIfNeeded()
        }
        .task(id: artworkRequestKey) {
            await loadArtworksIfNeeded()
        }
        .task(id: profileThemeImageURL) {
            await updateProfileAccent()
        }
        .alert("Action Failed", isPresented: actionErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(displayedError ?? "Unknown error")
        }
        .confirmationDialog(
            "Block this artist?",
            isPresented: $showsBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block Artist", role: .destructive) {
                guard case let .loaded(detail) = detailState else { return }
                localBlocks.block(user: detail.user)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This artist's artworks and user entries will be hidden in Hanairo.")
        }
    }

    private func loadingContent(_ user: PixivUser?) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.secondary.opacity(0.055)
                    .ignoresSafeArea()

                if let user {
                    ProgressiveFadeImageView(url: user.profileImageURLs.medium)
                        .frame(
                            width: proxy.size.width,
                            height: backgroundHeight(in: proxy)
                        )

                    loadingProfile(user, availableSize: proxy.size)
                } else {
                    ProgressView("Loading artist…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
#if os(iOS)
        .ignoresSafeArea(edges: .top)
#endif
    }

    private func loadingProfile(
        _ user: PixivUser,
        availableSize: CGSize
    ) -> some View {
        let usesLandscapeLayout = usesLandscapeLayout(in: availableSize)
        let profileWidth = usesLandscapeLayout
            ? min(max(availableSize.width * 0.36, 360), 480)
            : availableSize.width

        return ZStack(alignment: .top) {
            RemoteImageView(url: user.profileImageURLs.medium)
                .frame(width: 78, height: 78)
                .clipShape(Circle())
                .clipped()
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 4))
                .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
                .padding(.top, 168)

            VStack(spacing: 8) {
                Text(user.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(.ultraThinMaterial, in: Capsule())

                Text("@\(user.account)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView("Loading artist profile…")
                    .font(.subheadline)
                    .padding(.top, 42)
            }
            .padding(.top, 240)
            .padding(.horizontal, 20)
        }
        .frame(width: profileWidth, height: availableSize.height, alignment: .top)
        .padding(.leading, usesLandscapeLayout ? 16 : 0)
    }

    private func userContent(_ detail: PixivUserDetail) -> some View {
        GeometryReader { proxy in
            let usesLandscapeLayout = usesLandscapeLayout(in: proxy.size)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if usesLandscapeLayout {
                        landscapeProfileOverview(detail, availableWidth: proxy.size.width)

                        artworkSection(
                            detail,
                            columnCount: 4,
                            usesMenuFilter: true
                        )
                        .padding(.horizontal)
                    } else {
                        UserProfileHeaderView(
                            detail: detail,
                            isCurrentUser: authentication.userID == detail.user.id
                        )

                        UserProfileDetailsView(detail: detail)
                            .padding(.horizontal)

                        artworkSection(
                            detail,
                            columnCount: nil,
                            usesMenuFilter: false
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
                .background(alignment: .top) {
                    ProgressiveFadeImageView(url: backgroundURL(for: detail))
                        .frame(width: proxy.size.width, height: backgroundHeight(in: proxy))
                }
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await refresh()
            }
        }
        .background(Color.secondary.opacity(0.055))
#if os(iOS)
        .ignoresSafeArea(edges: .top)
#endif
    }

    private func landscapeProfileOverview(
        _ detail: PixivUserDetail,
        availableWidth: CGFloat
    ) -> some View {
        let profileWidth = min(max(availableWidth * 0.36, 360), 480)

        return HStack(alignment: .top, spacing: 20) {
            UserProfileHeaderView(
                detail: detail,
                isCurrentUser: authentication.userID == detail.user.id
            )
            .frame(width: profileWidth)

            UserProfileDetailsView(detail: detail)
                .padding(.top, 168)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal)
    }

    private func artworkSection(
        _ detail: PixivUserDetail,
        columnCount: Int?,
        usesMenuFilter: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !usesMenuFilter {
                Picker("Artist Content", selection: $selectedSection) {
                    ForEach(AuthorArtworkSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
            }

            artworkContent(
                detail,
                columnCount: columnCount,
                usesMenuFilter: usesMenuFilter
            )
        }
    }

    private func backgroundURL(for detail: PixivUserDetail) -> URL? {
        detail.profile.backgroundImageURL
            ?? artworks.items.first?.previewURL
            ?? detail.user.profileImageURLs.medium
    }

    private func backgroundHeight(in proxy: GeometryProxy) -> CGFloat {
        max(proxy.size.height * settings.profileBackgroundScreenRatio, 300)
    }

    @ViewBuilder
    private func artworkContent(
        _ detail: PixivUserDetail,
        columnCount: Int?,
        usesMenuFilter: Bool
    ) -> some View {
        HStack {
            Text(selectedSection.heading)
                .font(.title2.weight(.bold))
            Text(selectedSection.count(in: detail.profile), format: .number)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            if usesMenuFilter {
                Menu {
                    Picker("Artist Content", selection: $selectedSection) {
                        ForEach(AuthorArtworkSection.allCases) { section in
                            Label(section.title, systemImage: section.systemImage)
                                .tag(section)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Label(selectedSection.title, systemImage: selectedSection.systemImage)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 42)
                    .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }

        switch artworks.phase {
        case .idle, .loading:
            LoadingArtworkGrid()
        case let .failed(message):
            ErrorStateView(message: message, usesGlassButton: true) {
                Task { await retryArtworks() }
            }
            .frame(minHeight: 260)
        case .loaded:
            if artworks.items.isEmpty {
                ContentUnavailableView(selectedSection.emptyTitle, systemImage: selectedSection.systemImage)
                    .frame(minHeight: 260)
            } else {
                ArtworkGrid(
                    illustrations: artworks.items,
                    columnCount: columnCount,
                    onLoadMore: loadMoreArtworks
                ) { id in
                    await toggleBookmark(id: id)
                }
                PaginationStatusView(
                    isLoading: artworks.isLoadingMore,
                    errorMessage: artworks.loadMoreError,
                    usesGlassButton: true,
                    onRetry: loadMoreArtworks
                )
            }
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { displayedError != nil },
            set: {
                if !$0 {
                    actionError = nil
                    artworks.clearRefreshError()
                }
            }
        )
    }

    private var displayedError: String? {
        actionError ?? artworks.refreshError
    }

    private var navigationTitle: String {
        if case .failed = detailState {
            return "Artist Profile"
        }
        return ""
    }

    private var detailRequestKey: String {
        "user-detail|\(userID)|\(authentication.userID ?? 0)"
    }

    private var artworkRequestKey: String {
        "user-artworks|\(userID)|\(selectedSection.rawValue)|\(authentication.userID ?? 0)"
    }

    private var profileThemeImageURL: URL? {
        if case let .loaded(detail) = detailState {
            return detail.user.profileImageURLs.medium
        }
        return initialUser?.profileImageURLs.medium
    }

    private func updateProfileAccent() async {
        let activeURL = profileThemeImageURL
        guard let activeURL else {
            profileAccentColor = nil
            return
        }
        let color = await theme.accentColor(for: activeURL)
        guard !Task.isCancelled, activeURL == profileThemeImageURL else { return }
        profileAccentColor = color
    }

    private func loadDetailIfNeeded() async {
        guard completedDetailRequestKey != detailRequestKey else { return }
        await loadDetail(showsLoading: true)
    }

    private func loadArtworksIfNeeded() async {
        let activeRequestKey = artworkRequestKey
        let activeSection = selectedSection
        let activeUserID = userID
        await artworks.loadIfNeeded(requestKey: activeRequestKey) {
            try await firstPage(for: activeSection, userID: activeUserID)
        }
    }

    private func loadDetail(showsLoading: Bool) async {
        let activeRequestKey = detailRequestKey
        if showsLoading {
            detailState = .loading
        }
        do {
            let detail = try await repository.user(id: userID)
            guard !Task.isCancelled, activeRequestKey == detailRequestKey else { return }
            withAnimation(.easeInOut(duration: 0.24)) {
                detailState = .loaded(detail)
            }
            completedDetailRequestKey = activeRequestKey
        } catch is CancellationError {
            return
        } catch {
            guard activeRequestKey == detailRequestKey else { return }
            if showsLoading {
                withAnimation(.easeInOut(duration: 0.2)) {
                    detailState = .failed(error.localizedDescription)
                }
            } else {
                actionError = error.localizedDescription
            }
        }
    }

    private func refresh() async {
        let activeRequestKey = artworkRequestKey
        let activeSection = selectedSection
        let activeUserID = userID
        async let detailTask: Void = loadDetail(showsLoading: false)
        async let artworkTask: Void = artworks.reload(
            requestKey: activeRequestKey,
            showsInitialLoading: false
        ) {
            try await firstPage(for: activeSection, userID: activeUserID)
        }
        _ = await (detailTask, artworkTask)
    }

    private func retryDetail() async {
        await loadDetail(showsLoading: true)
    }

    private func retryArtworks() async {
        let activeRequestKey = artworkRequestKey
        let activeSection = selectedSection
        let activeUserID = userID
        await artworks.reload(requestKey: activeRequestKey, showsInitialLoading: true) {
            try await firstPage(for: activeSection, userID: activeUserID)
        }
    }

    private func loadMoreArtworks() async {
        let activeRequestKey = artworkRequestKey
        await artworks.loadMore(requestKey: activeRequestKey) { nextURL in
            try await repository.illustrations(nextURL: nextURL)
        }
    }

    private func firstPage(
        for section: AuthorArtworkSection,
        userID: Int
    ) async throws -> PixivPage<PixivIllustration> {
        switch section {
        case .illustrations:
            try await repository.userWorks(id: userID, type: .illustration)
        case .manga:
            try await repository.userWorks(id: userID, type: .manga)
        case .bookmarks:
            try await repository.publicBookmarks(userID: userID)
        }
    }

    private func toggleBookmark(id: Int) async {
        guard let illustration = artworks.item(id: id) else { return }
        do {
            let isBookmarked = try await repository.toggleBookmark(illustration)
            artworks.updateItem(id: id) { $0.isBookmarked = isBookmarked }
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func usesLandscapeLayout(in size: CGSize) -> Bool {
        guard
            size.width >= 900,
            size.width > size.height
        else {
            return false
        }
#if os(iOS)
        return UIDevice.current.userInterfaceIdiom != .phone
#else
        return true
#endif
    }
}

private enum AuthorArtworkSection: String, CaseIterable, Identifiable {
    case illustrations
    case manga
    case bookmarks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .illustrations: "Illustrations"
        case .manga: "Manga"
        case .bookmarks: "Bookmarks"
        }
    }

    var heading: String {
        switch self {
        case .illustrations: "Artworks"
        case .manga: "Manga"
        case .bookmarks: "Bookmarks"
        }
    }

    func count(in profile: PixivUserProfile) -> Int {
        switch self {
        case .illustrations: profile.totalIllusts
        case .manga: profile.totalManga
        case .bookmarks: profile.totalPublicBookmarks
        }
    }

    var emptyTitle: String {
        switch self {
        case .illustrations: "No Public Illustrations"
        case .manga: "No Public Manga"
        case .bookmarks: "No Public Bookmarks"
        }
    }

    var systemImage: String {
        switch self {
        case .illustrations: "photo.on.rectangle.angled"
        case .manga: "book.pages"
        case .bookmarks: "heart"
        }
    }
}

#Preview("Artist Profile") {
    NavigationStack {
        UserDetailView(userID: 101)
    }
    .withPreviewDependencies()
}
