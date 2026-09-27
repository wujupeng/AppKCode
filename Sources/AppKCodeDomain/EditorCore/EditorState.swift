import Foundation

public final class EditorState: @unchecked Sendable {
    public let document: EditorCoreDocument
    public let cursor: Cursor
    public let selection: Selection
    public let undoManager: EditorUndoManager
    public let searchEngine: SearchEngine
    public var scrollPosition: CGPoint = .zero
    public var fontSize: CGFloat = 13
    public var showLineNumbers: Bool = true
    public var highlightCurrentLine: Bool = true

    public init(document: EditorCoreDocument) {
        self.document = document
        self.cursor = Cursor()
        self.selection = Selection()
        self.undoManager = EditorUndoManager()
        self.searchEngine = SearchEngine()
    }

    public func insertText(_ text: String, at location: TextLocation? = nil) {
        let insertLocation = location ?? cursor.location
        let range = TextRange(location: insertLocation)
        let original = document.buffer.substring(range: range)
        let op = EditOperation(type: .insert, range: range, text: text, originalText: original)
        let transaction = EditTransaction(operations: [op])
        transaction.apply(to: document)
        undoManager.record(transaction)
        let newOffset = insertLocation.offset + text.count
        cursor.location = document.buffer.locationFromOffset(newOffset)
    }

    public func deleteBackward() {
        guard cursor.location.offset > 0 else { return }
        let prevOffset = cursor.location.offset - 1
        let prevLoc = document.buffer.locationFromOffset(prevOffset)
        let range = TextRange(start: prevLoc, end: cursor.location)
        let original = document.buffer.substring(range: range)
        let op = EditOperation(type: .delete, range: range, text: "", originalText: original)
        let transaction = EditTransaction(operations: [op])
        transaction.apply(to: document)
        undoManager.record(transaction)
        cursor.location = prevLoc
    }

    public func undo() {
        undoManager.undo(document: document)
        cursor.location = TextLocation(line: 0, column: 0, offset: 0)
    }

    public func redo() {
        undoManager.redo(document: document)
    }

    public func find(_ query: String, options: SearchOptions = SearchOptions()) -> [SearchResult] {
        searchEngine.find(query: query, in: document.buffer, options: options)
    }

    public func replaceAll(_ query: String, with replacement: String, options: SearchOptions = SearchOptions()) -> Int {
        searchEngine.replaceAll(query: query, with: replacement, in: document, options: options)
    }

    public func autoIndent() {
        let currentLine = document.buffer.line(cursor.location.line)
        let indent = String(currentLine.prefix { $0 == " " || $0 == "\t" })
        if !indent.isEmpty {
            insertText(indent)
        }
    }

    public func tab() {
        insertText("    ")
    }

    public func unindent() {
        let line = document.buffer.line(cursor.location.line)
        if line.hasPrefix("    ") {
            let range = TextRange(
                start: TextLocation(line: cursor.location.line, column: 0, offset: cursor.location.offset - cursor.location.column),
                end: TextLocation(line: cursor.location.line, column: 4, offset: cursor.location.offset - cursor.location.column + 4)
            )
            document.replace(range: range, with: "")
        } else if line.hasPrefix("\t") {
            let range = TextRange(
                start: TextLocation(line: cursor.location.line, column: 0, offset: cursor.location.offset - cursor.location.column),
                end: TextLocation(line: cursor.location.line, column: 1, offset: cursor.location.offset - cursor.location.column + 1)
            )
            document.replace(range: range, with: "")
        }
    }
}