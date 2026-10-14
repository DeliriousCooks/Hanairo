import Foundation

enum LibrarySection: String, CaseIterable, Identifiable {
    case bookmarks
    case followingFeed
    case followingUsers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookmarks: "Bookmarks"
        case .followingFeed: "Feed"
        case .followingUsers: "Following"
        }
    }
}
