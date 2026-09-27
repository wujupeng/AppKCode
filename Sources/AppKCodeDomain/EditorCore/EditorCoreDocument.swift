import Foundation

public final class EditorCoreDocument: @unchecked Sendable {
    public let id = UUID()
    public let url: URL
    public private(set) var buffer: TextBuffer
    public var isDirty: Bool = false
    public let encoding: StringEncoding
    public var language: String

    public init(url: URL, content: String = "", encoding: StringEncoding = .utf8) {
        self.url = url
        self.buffer = TextBuffer(content)
        self.encoding = encoding
        self.language = LanguageIdentifier.identify(url: url)
    }

    public var displayName: String {
        let name = url.lastPathComponent
        return isDirty ? "\(name) •" : name
    }

    public var content: String { buffer.text }

    public static func load(from url: URL, maxBytes: Int = 50 * 1024 * 1024) throws -> EditorCoreDocument {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AppKError.fileNotFound(url: url.path)
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? Int) ?? 0
        if fileSize > maxBytes {
            let truncated = try String(contentsOf: url, encoding: .utf8)
            let limited = String(truncated.prefix(maxBytes))
            let doc = EditorCoreDocument(url: url, content: limited)
            doc.isDirty = false
            return doc
        }
        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
        return EditorCoreDocument(url: url, content: content)
    }

    public func save() throws {
        let data = Data(buffer.text.utf8)
        try data.write(to: url)
        isDirty = false
    }

    public func replaceContent(_ newContent: String) {
        buffer = TextBuffer(newContent)
        isDirty = true
    }

    public func replace(range: TextRange, with text: String) {
        buffer.replace(range: range, with: text)
        isDirty = true
    }
}