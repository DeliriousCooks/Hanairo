import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationRequired
    case server(statusCode: Int, message: String)
    case decoding(String)
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid request URL"
        case .invalidResponse:
            "The server returned an unrecognized response"
        case .authenticationRequired:
            "Please sign in to your Pixiv account first"
        case let .server(statusCode, message):
            message.isEmpty ? "Request failed (\(statusCode))" : message
        case let .decoding(message):
            "Failed to parse data: \(message)"
        case .invalidImage:
            "Image data couldn't be read"
        }
    }
}
