import Foundation

enum PixivSearchTarget: String, CaseIterable, Identifiable, Codable, Sendable {
    case partialTag = "partial_match_for_tags"
    case exactTag = "exact_match_for_tags"
    case titleAndCaption = "title_and_caption"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .partialTag: "Partial Tag Match"
        case .exactTag: "Exact Tag Match"
        case .titleAndCaption: "Title & Caption"
        }
    }
}

enum PixivSearchSort: String, CaseIterable, Identifiable, Codable, Sendable {
    case newest = "date_desc"
    case oldest = "date_asc"
    case popular = "popular_desc"
    case popularAmongMen = "popular_male_desc"
    case popularAmongWomen = "popular_female_desc"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Newest First"
        case .oldest: "Oldest First"
        case .popular: "Most Popular"
        case .popularAmongMen: "Popular Among Men"
        case .popularAmongWomen: "Popular Among Women"
        }
    }

    var requiresPremium: Bool {
        switch self {
        case .newest, .oldest: false
        case .popular, .popularAmongMen, .popularAmongWomen: true
        }
    }
}

enum PixivSearchMediaFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all
    case illustrations
    case manga
    case ugoira

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Artworks"
        case .illustrations: "Illustrations Only"
        case .manga: "Manga Only"
        case .ugoira: "Ugoira Only"
        }
    }

    func includes(_ illustration: PixivIllustration) -> Bool {
        switch self {
        case .all: true
        case .illustrations: illustration.type == "illust"
        case .manga: illustration.type == "manga"
        case .ugoira: illustration.isUgoira
        }
    }
}

enum PixivSearchAIFilter: Int, CaseIterable, Identifiable, Codable, Sendable {
    case all = 0
    case excludesAI = 1

    var id: Int { rawValue }
    var title: String { self == .all ? "Include AI Artworks" : "Exclude AI Artworks" }
}

enum PixivBookmarkThreshold: Int, CaseIterable, Identifiable, Codable, Sendable {
    case any = 0
    case oneHundred = 100
    case fiveHundred = 500
    case oneThousand = 1_000
    case fiveThousand = 5_000
    case tenThousand = 10_000

    var id: Int { rawValue }
    var title: String { self == .any ? "Any" : "At least \(rawValue) bookmarks" }
}

struct PixivSearchOptions: Hashable, Codable, Sendable {
    var target: PixivSearchTarget = .partialTag
    var sort: PixivSearchSort = .newest
    var mediaFilter: PixivSearchMediaFilter = .all
    var aiFilter: PixivSearchAIFilter = .all
    var bookmarkThreshold: PixivBookmarkThreshold = .any
    var usesDateRange = false
    var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate = Date()

    var isDefault: Bool {
        target == .partialTag
            && sort == .newest
            && mediaFilter == .all
            && aiFilter == .all
            && bookmarkThreshold == .any
            && !usesDateRange
    }

    func effectiveWord(_ word: String) -> String {
        guard bookmarkThreshold != .any else { return word }
        return "\(word) \(bookmarkThreshold.rawValue)users入り"
    }
}

struct SearchAutocompleteResponse: Decodable, Sendable {
    let tags: [PixivTag]
}
