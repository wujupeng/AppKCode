import Foundation

public final class Cursor: @unchecked Sendable {
    public var location: TextLocation
    public var isVisible: Bool = true

    public init(location: TextLocation = .zero) {
        self.location = location
    }

    public func move(to location: TextLocation) {
        self.location = location
    }

    public func moveByOffset(_ delta: Int, in buffer: TextBuffer) {
        let newOffset = max(0, min(location.offset + delta, buffer.length))
        location = buffer.locationFromOffset(newOffset)
    }
}