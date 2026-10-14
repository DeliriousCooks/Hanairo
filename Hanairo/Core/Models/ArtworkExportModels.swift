import Foundation
import UniformTypeIdentifiers

enum ArtworkExportFormat: String, Sendable {
    case zip
    case pdf

    var contentType: UTType {
        switch self {
        case .zip: .zip
        case .pdf: .pdf
        }
    }

    var fileExtension: String { rawValue }
}

struct PreparedArtworkExport: Sendable {
    let fileURL: URL
    let format: ArtworkExportFormat
    let document: ArtworkExportDocument
}

nonisolated enum ArtworkExportError: LocalizedError, Sendable {
    case noAvailablePages
    case missingPage(Int)
    case cannotCreateOutput
    case invalidImage(Int)
    case invalidFilename
    case archiveTooLarge
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .noAvailablePages:
            "There are no images to export"
        case let .missingPage(index):
            "Page \(index + 1) has no original image URL"
        case .cannotCreateOutput:
            "Couldn't create the export file"
        case let .invalidImage(index):
            "Page \(index + 1) is not a valid image"
        case .invalidFilename:
            "Couldn't generate a valid archive file name"
        case .archiveTooLarge:
            "The artwork is too large for the ZIP format"
        case .compressionFailed:
            "An error occurred while compressing images"
        }
    }
}
