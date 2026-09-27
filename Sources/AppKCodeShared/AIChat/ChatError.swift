import Foundation

public enum ChatError: Error, Sendable, Equatable {
    case modelUnavailable
    case timeout
    case rateLimited
    case invalidResponse
    case contextTooLarge
    case cancelled
    case networkError(String)

    public var localizedDescription: String {
        switch self {
        case .modelUnavailable:
            return "Model is unavailable. Please check the model endpoint configuration."
        case .timeout:
            return "Request timed out. Please retry."
        case .rateLimited:
            return "Rate limit exceeded. Please wait and retry."
        case .invalidResponse:
            return "Received an invalid response from the model."
        case .contextTooLarge:
            return "Context is too large for the model's token limit."
        case .cancelled:
            return "Request was cancelled."
        case .networkError(let detail):
            return "Network error: \(detail)"
        }
    }
}