import Foundation

struct ArtworkDownloadPage: Codable, Hashable, Sendable {
    let pageIndex: Int
    let url: URL
}

struct DownloadedArtworkPage: Codable, Hashable, Identifiable, Sendable {
    let pageIndex: Int
    let fileName: String?
    let byteCount: Int64

    var id: Int { pageIndex }
}

struct ArtworkDownloadTask: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let illustrationID: Int
    let title: String
    let artistName: String
    let previewURL: URL?
    let pages: [ArtworkDownloadPage]
    let totalArtworkPageCount: Int
    let destination: ArtworkDownloadDestination
    var status: ArtworkDownloadTaskStatus
    let createdAt: Date
    var startedAt: Date?
    var completedPageIndexes: Set<Int>
    var currentPageIndex: Int?
    var downloadedBytes: Int64
    var errorMessage: String?

    var progress: Double {
        guard !pages.isEmpty else { return 0 }
        return min(Double(completedPageIndexes.count) / Double(pages.count), 1)
    }

    var statusText: String {
        switch status {
        case .queued:
            "Waiting to download"
        case .downloading:
            if let currentPageIndex {
                "Downloading page \(currentPageIndex + 1)"
            } else {
                "Preparing"
            }
        case .paused:
            "Paused"
        case .failed:
            errorMessage ?? "Download failed"
        }
    }

    var progressText: String {
        "\(completedPageIndexes.count)/\(pages.count) pages"
    }
}

enum ArtworkDownloadTaskStatus: String, Codable, Hashable, Sendable {
    case queued
    case downloading
    case paused
    case failed

    var canRun: Bool { self == .queued }
}

struct ArtworkDownloadRecord: Codable, Identifiable, Hashable, Sendable {
    let illustrationID: Int
    let title: String
    let artistName: String
    let previewURL: URL?
    let destination: ArtworkDownloadDestination
    var pages: [DownloadedArtworkPage]
    let totalArtworkPageCount: Int
    var totalBytes: Int64
    var updatedAt: Date

    var id: String {
        "\(illustrationID)-\(destination.rawValue)"
    }

    var detailText: String {
        let size = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let progress = "\(pages.count)/\(totalArtworkPageCount) pages"
        return totalBytes > 0 ? "\(progress) · \(size)" : progress
    }

    var isComplete: Bool {
        pages.count >= totalArtworkPageCount
    }
}

enum ArtworkDownloadEnqueueResult: Equatable {
    case queued(Int)
    case alreadyQueued
    case alreadyDownloaded
    case noAvailablePages

    var message: String {
        switch self {
        case let .queued(count): "Added to download queue: \(count) pages"
        case .alreadyQueued: "This artwork is already in the download queue"
        case .alreadyDownloaded: "The selected images have already been downloaded"
        case .noAvailablePages: "No download URLs available"
        }
    }
}

struct ArtworkDownloadStorageUsage: Sendable {
    let filesBytes: Int64
    let metadataBytes: Int64

    var totalBytes: Int64 { filesBytes + metadataBytes }
}
