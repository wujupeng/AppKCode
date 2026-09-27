import Foundation

public struct TextDocumentIdentifier: Codable, Equatable, Sendable {
    public let uri: String

    public init(uri: String) {
        self.uri = uri
    }

    public init(url: URL) {
        self.uri = url.absoluteString
    }

    public var fileURL: URL? {
        URL(string: uri)
    }
}