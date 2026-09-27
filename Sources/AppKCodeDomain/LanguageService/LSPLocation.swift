import Foundation

public struct LSPLocation: Codable, Equatable, Sendable {
    public let uri: String
    public let range: LSPRange

    public init(uri: String, range: LSPRange) {
        self.uri = uri
        self.range = range
    }

    public var fileURL: URL? {
        URL(string: uri)
    }
}