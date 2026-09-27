import Foundation

public struct HoverInfo: Codable, Equatable, Sendable {
    public let contents: String
    public let range: LSPRange?

    public init(contents: String, range: LSPRange? = nil) {
        self.contents = contents
        self.range = range
    }
}