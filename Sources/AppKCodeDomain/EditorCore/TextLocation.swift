import Foundation

public struct TextLocation: Comparable, Hashable, Sendable {
    public let line: Int
    public let column: Int
    public let offset: Int

    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }

    public static let zero = TextLocation(line: 0, column: 0, offset: 0)

    public static func < (lhs: TextLocation, rhs: TextLocation) -> Bool {
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        return lhs.column < rhs.column
    }
}