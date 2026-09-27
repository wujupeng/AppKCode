import XCTest
@testable import AppKCodeDomain
import AppKCodeInfrastructure

final class LSPDataModelTests: XCTestCase {
    func testLSPPosition() {
        let pos = LSPPosition(line: 5, character: 10)
        XCTAssertEqual(pos.line, 5)
        XCTAssertEqual(pos.character, 10)
    }

    func testLSPRange() {
        let range = LSPRange(start: LSPPosition(line: 0, character: 0),
                             end: LSPPosition(line: 0, character: 5))
        XCTAssertEqual(range.start.character, 0)
        XCTAssertEqual(range.end.character, 5)
    }

    func testLSPLocation() {
        let loc = LSPLocation(uri: "file:///test.swift", range: LSPRange(
            start: LSPPosition(line: 0, character: 0),
            end: LSPPosition(line: 0, character: 5)))
        XCTAssertEqual(loc.uri, "file:///test.swift")
        XCTAssertNotNil(loc.fileURL)
    }

    func testTextDocumentIdentifier() {
        let url = URL(fileURLWithPath: "/tmp/test.swift")
        let doc = TextDocumentIdentifier(url: url)
        XCTAssertTrue(doc.uri.hasPrefix("file://"))
        XCTAssertNotNil(doc.fileURL)
    }

    func testCompletionItem() {
        let item = CompletionItem(label: "foo", kind: .function, detail: "func foo()")
        XCTAssertEqual(item.label, "foo")
        XCTAssertEqual(item.kind, .function)
    }

    func testCompletionItemKindValues() {
        XCTAssertEqual(CompletionItemKind.text.rawValue, 1)
        XCTAssertEqual(CompletionItemKind.method.rawValue, 2)
        XCTAssertEqual(CompletionItemKind.function.rawValue, 3)
        XCTAssertEqual(CompletionItemKind.variable.rawValue, 5)
        XCTAssertEqual(CompletionItemKind.class.rawValue, 6)
        XCTAssertEqual(CompletionItemKind.struct.rawValue, 21)
    }

    func testDiagnosticSeverityValues() {
        XCTAssertEqual(DiagnosticSeverity.error.rawValue, 1)
        XCTAssertEqual(DiagnosticSeverity.warning.rawValue, 2)
        XCTAssertEqual(DiagnosticSeverity.information.rawValue, 3)
        XCTAssertEqual(DiagnosticSeverity.hint.rawValue, 4)
    }

    func testSymbolKindValues() {
        XCTAssertEqual(SymbolKind.file.rawValue, 1)
        XCTAssertEqual(SymbolKind.class.rawValue, 5)
        XCTAssertEqual(SymbolKind.function.rawValue, 12)
        XCTAssertEqual(SymbolKind.variable.rawValue, 13)
        XCTAssertEqual(SymbolKind.struct.rawValue, 23)
    }

    func testDiagnostic() {
        let diag = Diagnostic(
            range: LSPRange(start: LSPPosition(line: 0, character: 0),
                           end: LSPPosition(line: 0, character: 5)),
            severity: .error,
            source: "sourcekit-lsp",
            message: "Type mismatch")
        XCTAssertEqual(diag.severity, .error)
        XCTAssertEqual(diag.message, "Type mismatch")
    }

    func testHoverInfo() {
        let hover = HoverInfo(contents: "func foo() -> Int")
        XCTAssertEqual(hover.contents, "func foo() -> Int")
        XCTAssertNil(hover.range)
    }

    func testSignatureHelp() {
        let sig = SignatureInformation(label: "foo(a: Int, b: Int)", parameters: [
            ParameterInformation(label: "a: Int"),
            ParameterInformation(label: "b: Int")
        ])
        let help = SignatureHelp(signatures: [sig], activeSignature: 0, activeParameter: 0)
        XCTAssertEqual(help.signatures.count, 1)
        XCTAssertEqual(help.signatures[0].parameters.count, 2)
    }

    func testLSPWorkspaceEdit() {
        let edit = LSPWorkspaceEdit(changes: [
            "file:///test.swift": [LSPTextEdit(
                range: LSPRange(start: LSPPosition(line: 0, character: 0),
                               end: LSPPosition(line: 0, character: 3)),
                newText: "bar"
            )]
        ])
        XCTAssertEqual(edit.changes.count, 1)
    }

    func testLanguageServerStatus() {
        XCTAssertTrue(LanguageServerStatus.running.isRunning)
        XCTAssertFalse(LanguageServerStatus.notStarted.isRunning)
        XCTAssertTrue(LanguageServerStatus.crashed(restartCount: 1).isCrashed)
        XCTAssertFalse(LanguageServerStatus.running.isCrashed)
    }
}