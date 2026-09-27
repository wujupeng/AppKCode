import Foundation

public final class Selection: @unchecked Sendable {
    public var range: TextRange

    public init(range: TextRange = TextRange(location: .zero)) {
        self.range = range
    }

    public var isEmpty: Bool { range.isEmpty }
    public var hasSelection: Bool { !isEmpty }

    public func set(range: TextRange) {
        self.range = range
    }

    public func clear(at location: TextLocation) {
        self.range = TextRange(location: location)
    }

    public func selectedText(in buffer: TextBuffer) -> String {
        buffer.substring(range: range)
    }
}