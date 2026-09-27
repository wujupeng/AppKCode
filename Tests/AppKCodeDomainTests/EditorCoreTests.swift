import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeShared

final class TextBufferTests: XCTestCase {
    func testEmptyBuffer() {
        let buffer = TextBuffer()
        XCTAssertEqual(buffer.length, 0)
        XCTAssertEqual(buffer.lineCount, 1)
        XCTAssertEqual(buffer.text, "")
    }

    func testSingleLine() {
        let buffer = TextBuffer("Hello World")
        XCTAssertEqual(buffer.length, 11)
        XCTAssertEqual(buffer.lineCount, 1)
        XCTAssertEqual(buffer.line(0), "Hello World")
    }

    func testMultiLine() {
        let buffer = TextBuffer("line1\nline2\nline3")
        XCTAssertEqual(buffer.lineCount, 3)
        XCTAssertEqual(buffer.line(0), "line1")
        XCTAssertEqual(buffer.line(1), "line2")
        XCTAssertEqual(buffer.line(2), "line3")
    }

    func testLocationFromOffset() {
        let buffer = TextBuffer("ab\ncd\nef")
        let loc0 = buffer.locationFromOffset(0)
        XCTAssertEqual(loc0.line, 0)
        XCTAssertEqual(loc0.column, 0)
        let loc3 = buffer.locationFromOffset(3)
        XCTAssertEqual(loc3.line, 1)
        XCTAssertEqual(loc3.column, 0)
        let loc5 = buffer.locationFromOffset(5)
        XCTAssertEqual(loc5.line, 1)
        XCTAssertEqual(loc5.column, 2)
    }

    func testInsert() {
        let buffer = TextBuffer("Hello")
        buffer.insert(" World", at: 5)
        XCTAssertEqual(buffer.text, "Hello World")
    }

    func testDelete() {
        let buffer = TextBuffer("Hello World")
        let range = TextRange(
            start: TextLocation(line: 0, column: 5, offset: 5),
            end: TextLocation(line: 0, column: 11, offset: 11)
        )
        buffer.delete(range: range)
        XCTAssertEqual(buffer.text, "Hello")
    }

    func testReplace() {
        let buffer = TextBuffer("Hello World")
        let range = TextRange(
            start: TextLocation(line: 0, column: 6, offset: 6),
            end: TextLocation(line: 0, column: 11, offset: 11)
        )
        buffer.replace(range: range, with: "Swift")
        XCTAssertEqual(buffer.text, "Hello Swift")
    }
}

final class EditorCoreDocumentTests: XCTestCase {
    func testCreateDocument() {
        let url = URL(fileURLWithPath: "/tmp/test.swift")
        let doc = EditorCoreDocument(url: url, content: "let x = 42")
        XCTAssertEqual(doc.content, "let x = 42")
        XCTAssertEqual(doc.language, "Swift")
        XCTAssertFalse(doc.isDirty)
        XCTAssertEqual(doc.displayName, "test.swift")
    }

    func testDirtyAfterEdit() {
        let url = URL(fileURLWithPath: "/tmp/test.swift")
        let doc = EditorCoreDocument(url: url, content: "let x = 42")
        doc.replaceContent("let x = 43")
        XCTAssertTrue(doc.isDirty)
        XCTAssertTrue(doc.displayName.contains("•"))
    }

    func testLanguageDetection() {
        XCTAssertEqual(EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/a.py"), content: "").language, "Python")
        XCTAssertEqual(EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/a.go"), content: "").language, "Go")
        XCTAssertEqual(EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/a.ts"), content: "").language, "TypeScript")
        XCTAssertEqual(EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/a.json"), content: "").language, "JSON")
        XCTAssertEqual(EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/a.md"), content: "").language, "Markdown")
    }

    func testLargeFileProtection() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("appk-large-\(UUID().uuidString).txt")
        let largeContent = String(repeating: "A", count: 100_000)
        try largeContent.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let doc = try EditorCoreDocument.load(from: tempFile, maxBytes: 50_000)
        XCTAssertLessThan(doc.content.count, 100_000, "Large file should be truncated")
    }
}

final class UndoManagerTests: XCTestCase {
    func testUndoRedo() {
        let url = URL(fileURLWithPath: "/tmp/test.swift")
        let doc = EditorCoreDocument(url: url, content: "Hello")
        let undo = EditorUndoManager()

        let range = TextRange(location: TextLocation(line: 0, column: 5, offset: 5))
        let op = EditOperation(type: .insert, range: range, text: " World", originalText: "")
        let transaction = EditTransaction(operations: [op])
        transaction.apply(to: doc)
        undo.record(transaction)
        XCTAssertEqual(doc.content, "Hello World")

        undo.undo(document: doc)
        XCTAssertEqual(doc.content, "Hello")

        undo.redo(document: doc)
        XCTAssertEqual(doc.content, "Hello World")
    }

    func testCanUndoCanRedo() {
        let undo = EditorUndoManager()
        XCTAssertFalse(undo.canUndo)
        XCTAssertFalse(undo.canRedo)

        let doc = EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/t.swift"), content: "")
        let op = EditOperation(type: .insert, range: TextRange(location: .zero), text: "x", originalText: "")
        let t = EditTransaction(operations: [op])
        undo.record(t)
        XCTAssertTrue(undo.canUndo)
        XCTAssertFalse(undo.canRedo)

        undo.undo(document: doc)
        XCTAssertFalse(undo.canUndo)
        XCTAssertTrue(undo.canRedo)
    }
}

final class SearchEngineTests: XCTestCase {
    func testFindSimple() {
        let buffer = TextBuffer("Hello World Hello Again")
        let engine = SearchEngine()
        let results = engine.find(query: "Hello", in: buffer)
        XCTAssertEqual(results.count, 2)
    }

    func testFindCaseInsensitive() {
        let buffer = TextBuffer("hello HELLO Hello")
        let engine = SearchEngine()
        let results = engine.find(query: "hello", in: buffer, options: SearchOptions(caseSensitive: false))
        XCTAssertEqual(results.count, 3)
    }

    func testFindCaseSensitive() {
        let buffer = TextBuffer("hello HELLO Hello")
        let engine = SearchEngine()
        let results = engine.find(query: "hello", in: buffer, options: SearchOptions(caseSensitive: true))
        XCTAssertEqual(results.count, 1)
    }

    func testReplaceAll() {
        let doc = EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/t.swift"), content: "foo bar foo baz foo")
        let engine = SearchEngine()
        let count = engine.replaceAll(query: "foo", with: "qux", in: doc)
        XCTAssertEqual(count, 3)
        XCTAssertEqual(doc.content, "qux bar qux baz qux")
    }

    func testFindEmptyQuery() {
        let buffer = TextBuffer("Hello World")
        let engine = SearchEngine()
        let results = engine.find(query: "", in: buffer)
        XCTAssertTrue(results.isEmpty)
    }
}

final class EditorStateTests: XCTestCase {
    func testInsertText() {
        let doc = EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/t.swift"), content: "Hello")
        let state = EditorState(document: doc)
        state.insertText(" World", at: TextLocation(line: 0, column: 5, offset: 5))
        XCTAssertEqual(doc.content, "Hello World")
        XCTAssertTrue(doc.isDirty)
    }

    func testDeleteBackward() {
        let doc = EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/t.swift"), content: "Hello")
        let state = EditorState(document: doc)
        state.cursor.location = TextLocation(line: 0, column: 5, offset: 5)
        state.deleteBackward()
        XCTAssertEqual(doc.content, "Hell")
    }

    func testUndoThroughState() {
        let doc = EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/t.swift"), content: "")
        let state = EditorState(document: doc)
        state.insertText("Hello")
        XCTAssertEqual(doc.content, "Hello")
        state.undo()
        XCTAssertEqual(doc.content, "")
    }

    func testFindThroughState() {
        let doc = EditorCoreDocument(url: URL(fileURLWithPath: "/tmp/t.swift"), content: "Hello World Hello")
        let state = EditorState(document: doc)
        let results = state.find("Hello")
        XCTAssertEqual(results.count, 2)
    }
}

final class LanguageIdentifierTests: XCTestCase {
    func testSupportedLanguages() {
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.swift"), "Swift")
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.m"), "Objective-C")
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.c"), "C")
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.cpp"), "C++")
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.py"), "Python")
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.go"), "Go")
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.js"), "JavaScript")
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.ts"), "TypeScript")
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.json"), "JSON")
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.yaml"), "YAML")
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.md"), "Markdown")
    }

    func testUnsupportedLanguage() {
        XCTAssertEqual(LanguageIdentifier.identify(filename: "test.unknown"), "Plain Text")
    }

    func testIsSupported() {
        XCTAssertTrue(LanguageIdentifier.isSupported("Swift"))
        XCTAssertFalse(LanguageIdentifier.isSupported("Plain Text"))
    }
}