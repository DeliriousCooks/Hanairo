import Foundation

enum PixivVisibility: String, CaseIterable, Identifiable, Codable, Sendable {
    case `public`
    case `private`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .public: "Public"
        case .private: "Private"
        }
    }
}

enum FollowingFeedScope: String, CaseIterable, Identifiable, Sendable {
    case all
    case `public`
    case `private`

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .public: "Public Following"
        case .private: "Private Following"
        }
    }
}

enum UserConnectionKind: String, CaseIterable, Identifiable, Hashable, Sendable {
    case following
    case followers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .following: "Following"
        case .followers: "Followers"
        }
    }

    var emptyTitle: String {
        switch self {
        case .following: "No Following Users Yet"
        case .followers: "No Followers Yet"
        }
    }
}

nonisolated struct PixivBookmarkDetailResponse: Decodable, Sendable {
    let detail: PixivBookmarkDetail

    enum CodingKeys: String, CodingKey {
        case detail = "bookmark_detail"
    }
}

nonisolated struct PixivBookmarkDetail: Decodable, Sendable {
    let isBookmarked: Bool
    let tags: [PixivBookmarkDetailTag]
    let visibility: PixivVisibility

    enum CodingKeys: String, CodingKey {
        case isBookmarked = "is_bookmarked"
        case tags
        case visibility = "restrict"
    }
}

nonisolated struct PixivBookmarkDetailTag: Decodable, Hashable, Sendable {
    let name: String
    let isRegistered: Bool

    enum CodingKeys: String, CodingKey {
        case name
        case isRegistered = "is_registered"
    }

    init(name: String, isRegistered: Bool) {
        self.name = name
        self.isRegistered = isRegistered
    }
}

nonisolated struct PixivBookmarkTagResponse: Decodable, Sendable {
    let tags: [PixivBookmarkTag]
    let nextURL: URL?

    enum CodingKeys: String, CodingKey {
        case tags = "bookmark_tags"
        case nextURL = "next_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tags = try container.decodeIfPresent([PixivBookmarkTag].self, forKey: .tags) ?? []
        let value = try container.decodeIfPresent(String.self, forKey: .nextURL)
        nextURL = value.flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }

    var page: PixivPage<PixivBookmarkTag> {
        PixivPage(items: tags, nextURL: nextURL)
    }
}

nonisolated struct PixivBookmarkTag: Decodable, Identifiable, Hashable, Sendable {
    let name: String
    let count: Int

    var id: String { name }
}

nonisolated struct PixivFollowDetailResponse: Decodable, Sendable {
    let detail: PixivFollowDetail

    enum CodingKeys: String, CodingKey {
        case detail = "follow_detail"
    }
}

nonisolated struct PixivFollowDetail: Decodable, Sendable {
    let isFollowed: Bool
    let visibility: PixivVisibility

    enum CodingKeys: String, CodingKey {
        case isFollowed = "is_followed"
        case visibility = "restrict"
    }
}
