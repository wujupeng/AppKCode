import Foundation

public final class TextBuffer: @unchecked Sendable {
    private var content: String
    private var lineStartOffsets: [Int] = [0]
    private let lock = NSLock()

    public init(_ content: String = "") {
        self.content = content
        rebuildLineIndex()
    }

    public var length: Int {
        lock.lock(); defer { lock.unlock() }
        return content.count
    }

    public var lineCount: Int {
        lock.lock(); defer { lock.unlock() }
        return lineStartOffsets.count
    }

    public var text: String {
        lock.lock(); defer { lock.unlock() }
        return content
    }

    public func line(_ index: Int) -> String {
        lock.lock(); defer { lock.unlock() }
        guard index >= 0 && index < lineStartOffsets.count else { return "" }
        let start = lineStartOffsets[index]
        let end = index + 1 < lineStartOffsets.count ? lineStartOffsets[index + 1] - 1 : content.count
        let startIdx = content.index(content.startIndex, offsetBy: start)
        let endIdx = content.index(content.startIndex, offsetBy: min(end, content.count))
        return String(content[startIdx..<endIdx])
    }

    public func locationFromOffset(_ offset: Int) -> TextLocation {
        lock.lock(); defer { lock.unlock() }
        let clampedOffset = max(0, min(offset, content.count))
        var line = 0
        for (i, lineStart) in lineStartOffsets.enumerated() {
            if lineStart <= clampedOffset { line = i } else { break }
        }
        let column = clampedOffset - lineStartOffsets[line]
        return TextLocation(line: line, column: column, offset: clampedOffset)
    }

    public func offsetFromLocation(_ location: TextLocation) -> Int {
        lock.lock(); defer { lock.unlock() }
        guard location.line >= 0 && location.line < lineStartOffsets.count else {
            return content.count
        }
        return lineStartOffsets[location.line] + location.column
    }

    public func replace(range: TextRange, with newText: String) {
        lock.lock()
        let startOffset = max(0, min(range.start.offset, content.count))
        let endOffset = max(startOffset, min(range.end.offset, content.count))
        let startIdx = content.index(content.startIndex, offsetBy: startOffset)
        let endIdx = content.index(content.startIndex, offsetBy: endOffset)
        content.replaceSubrange(startIdx..<endIdx, with: newText)
        rebuildLineIndex()
        lock.unlock()
    }

    public func insert(_ text: String, at offset: Int) {
        replace(range: TextRange(start: TextLocation(line: 0, column: 0, offset: offset),
                                  end: TextLocation(line: 0, column: 0, offset: offset)),
                with: text)
    }

    public func delete(range: TextRange) {
        replace(range: range, with: "")
    }

    public func substring(range: TextRange) -> String {
        lock.lock(); defer { lock.unlock() }
        let startOffset = max(0, min(range.start.offset, content.count))
        let endOffset = max(startOffset, min(range.end.offset, content.count))
        let startIdx = content.index(content.startIndex, offsetBy: startOffset)
        let endIdx = content.index(content.startIndex, offsetBy: endOffset)
        return String(content[startIdx..<endIdx])
    }

    private func rebuildLineIndex() {
        lineStartOffsets = [0]
        var idx = content.startIndex
        while idx < content.endIndex {
            if content[idx] == "\n" {
                let offset = content.distance(from: content.startIndex, to: idx) + 1
                lineStartOffsets.append(offset)
            }
            idx = content.index(after: idx)
        }
    }
}