import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case notFound
    case rateLimited
    case server(status: Int, message: String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL was invalid."
        case .unauthorized:
            return "Authentication failed. Check that your token is valid and has the `api` scope."
        case .notFound:
            return "The requested resource was not found."
        case .rateLimited:
            return "You've hit the GitLab API rate limit. Try again in a moment."
        case .server(let status, let message):
            return message ?? "The server returned an error (HTTP \(status))."
        case .decoding:
            return "The server response could not be read."
        case .transport(let error):
            return error.localizedDescription
        }
    }

    /// Errors that should bounce the user back to the login screen.
    var isAuthFailure: Bool {
        if case .unauthorized = self { return true }
        return false
    }
}
