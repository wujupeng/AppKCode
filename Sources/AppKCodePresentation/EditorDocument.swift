import Foundation
import AppKCodeShared

public final class EditorDocument: ObservableObject, Identifiable {
    public let id = UUID()
    public let url: URL
    @Published public var content: String
    @Published public var isDirty: Bool = false
    public let encoding: StringEncoding

    public init(url: URL, content: String = "", encoding: StringEncoding = .utf8) {
        self.url = url
        self.content = content
        self.encoding = encoding
    }

    public var displayName: String {
        let name = url.lastPathComponent
        return isDirty ? "\(name) •" : name
    }

    public static func load(from url: URL) throws -> EditorDocument {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AppKError.fileNotFound(url: url.path)
        }
        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
        return EditorDocument(url: url, content: content)
    }

    public func save() throws {
        let data = Data(content.utf8)
        try data.write(to: url)
        isDirty = false
    }

    public func saveAs(to newURL: URL) throws {
        let data = Data(content.utf8)
        try data.write(to: newURL)
        isDirty = false
    }

    public func updateContent(_ newContent: String) {
        if newContent != content {
            content = newContent
            isDirty = true
        }
    }
}