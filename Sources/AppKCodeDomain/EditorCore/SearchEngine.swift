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
        var results: [SearchResult] = []
        var searchRange = content.startIndex..<content.endIndex

        let compareFn: (String, String) -> Bool = options.caseSensitive
            ? { $0 == $1 }
            : { $0.lowercased() == $1.lowercased() }

        let queryLen = query.count
        while let range = content.range(of: query, options: options.caseSensitive ? [] : .caseInsensitive, range: searchRange) {
            let offset = content.distance(from: content.startIndex, to: range.lowerBound)
            let start = buffer.locationFromOffset(offset)
            let end = buffer.locationFromOffset(offset + queryLen)
            results.append(SearchResult(range: TextRange(start: start, end: end), matchedText: String(content[range])))
            searchRange = range.upperBound..<content.endIndex
            if !options.wrapAround && results.count > 10000 { break }
        }
        _ = compareFn
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