import Foundation

public struct SearchResult: Hashable, Sendable {
    public let range: TextRange
    public let matchedText: String

    public init(range: TextRange, matchedText: String) {
        self.range = range
        self.matchedText = matchedText
    }
}

public final class SearchEngine: @unchecked Sendable {
    public init() {}

    public func find(query: String, in buffer: TextBuffer, options: SearchOptions = SearchOptions()) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        let content = buffer.text

        let contentBytes = Array(content.utf8)
        let queryBytes = Array(query.utf8)

        guard queryBytes.count <= contentBytes.count else { return [] }

        let matchOffsets: [Int]
        if options.caseSensitive {
            matchOffsets = boyerMooreHorspool(pattern: queryBytes, text: contentBytes)
        } else {
            matchOffsets = boyerMooreHorspoolCaseInsensitive(pattern: queryBytes, text: contentBytes)
        }

        if matchOffsets.isEmpty { return [] }

        let lineStartOffsets = buildLineOffsets(content)

        var results: [SearchResult] = []
        results.reserveCapacity(matchOffsets.count)

        let queryLen = query.count
        let isASCII = content.allSatisfy { $0.isASCII }

        for byteOffset in matchOffsets {
            let charOffset: Int
            if isASCII {
                charOffset = byteOffset
            } else {
                charOffset = content.utf8.prefix(byteOffset).count
            }

            let start = locationFromOffset(charOffset, lineStartOffsets: lineStartOffsets)
            let end = locationFromOffset(charOffset + queryLen, lineStartOffsets: lineStartOffsets)
            results.append(SearchResult(range: TextRange(start: start, end: end), matchedText: query))
        }

        return results
    }

    public func replaceAll(query: String, with replacement: String, in document: EditorCoreDocument, options: SearchOptions = SearchOptions()) -> Int {
        let results = find(query: query, in: document.buffer, options: options)
        guard !results.isEmpty else { return 0 }
        var newContent = document.buffer.text
        var offsetAdjustment = 0
        for result in results {
            let startOffset = result.range.start.offset + offsetAdjustment
            let endOffset = result.range.end.offset + offsetAdjustment
            let startIdx = newContent.index(newContent.startIndex, offsetBy: startOffset)
            let endIdx = newContent.index(newContent.startIndex, offsetBy: endOffset)
            newContent.replaceSubrange(startIdx..<endIdx, with: replacement)
            offsetAdjustment += replacement.count - (endOffset - startOffset)
        }
        document.replaceContent(newContent)
        return results.count
    }

    private func boyerMooreHorspool(pattern: [UInt8], text: [UInt8]) -> [Int] {
        let m = pattern.count
        let n = text.count
        guard m > 0 && m <= n else { return [] }

        var shift = [UInt8](repeating: UInt8(m), count: 256)
        for i in 0..<(m - 1) {
            shift[Int(pattern[i])] = UInt8(m - 1 - i)
        }

        var results: [Int] = []
        var j = 0
        while j <= n - m {
            var i = m - 1
            while i >= 0 && pattern[i] == text[j + i] {
                i -= 1
            }
            if i < 0 {
                results.append(j)
                j += m
            } else {
                j += Int(shift[Int(text[j + m - 1])])
            }
        }
        return results
    }

    private func boyerMooreHorspoolCaseInsensitive(pattern: [UInt8], text: [UInt8]) -> [Int] {
        let m = pattern.count
        let n = text.count
        guard m > 0 && m <= n else { return [] }

        let lowerPattern = pattern.map { toLower($0) }

        var shift = [UInt8](repeating: UInt8(m), count: 256)
        for i in 0..<(m - 1) {
            shift[Int(lowerPattern[i])] = UInt8(m - 1 - i)
        }

        var results: [Int] = []
        var j = 0
        while j <= n - m {
            var i = m - 1
            while i >= 0 && lowerPattern[i] == toLower(text[j + i]) {
                i -= 1
            }
            if i < 0 {
                results.append(j)
                j += m
            } else {
                j += Int(shift[Int(toLower(text[j + m - 1]))])
            }
        }
        return results
    }

    private func toLower(_ b: UInt8) -> UInt8 {
        if b >= 0x41 && b <= 0x5A {
            return b + 0x20
        }
        return b
    }

    private func buildLineOffsets(_ content: String) -> [Int] {
        var offsets: [Int] = [0]
        var charOffset = 0
        for ch in content {
            if ch == "\n" {
                offsets.append(charOffset + 1)
            }
            charOffset += 1
        }
        return offsets
    }

    private func locationFromOffset(_ offset: Int, lineStartOffsets: [Int]) -> TextLocation {
        var line = 0
        var lo = 0
        var hi = lineStartOffsets.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lineStartOffsets[mid] <= offset {
                line = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        let column = offset - lineStartOffsets[line]
        return TextLocation(line: line, column: column, offset: offset)
    }
}

public struct SearchOptions: Sendable {
    public var caseSensitive: Bool = false
    public var wholeWord: Bool = false
    public var regex: Bool = false
    public var wrapAround: Bool = true

    public init(caseSensitive: Bool = false, wholeWord: Bool = false, regex: Bool = false, wrapAround: Bool = true) {
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.regex = regex
        self.wrapAround = wrapAround
    }
}
