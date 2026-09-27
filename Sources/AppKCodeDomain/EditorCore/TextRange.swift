import Foundation

public struct TextRange: Hashable, Sendable {
    public let start: TextLocation
    public let end: TextLocation

    public init(start: TextLocation, end: TextLocation) {
        self.start = start
        self.end = end
    }

    public init(location: TextLocation) {
        self.start = location
        self.end = location
    }

    public var isEmpty: Bool { start == end }
    public var isCollapsed: Bool { start == end }

    public func contains(_ location: TextLocation) -> Bool {
        location >= start && location <= end
    }

    public var normalized: TextRange {
        start <= end ? self : TextRange(start: end, end: start)
    }
}