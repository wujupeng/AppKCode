import Foundation
import AppKCodeInfrastructure

public protocol LanguageService: AnyObject {
    var serverStatus: LanguageServerStatus { get }

    func initialize(workspaceRoot: URL) async throws
    func shutdown() async throws
    func openDocument(_ document: TextDocumentIdentifier, languageId: String, version: Int, text: String) async throws
    func closeDocument(_ document: TextDocumentIdentifier) async throws
    func updateDocument(_ document: TextDocumentIdentifier, version: Int, content: String) async throws

    func completion(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> [CompletionItem]
    func hover(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> HoverInfo?
    func definition(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> [LSPLocation]
    func declaration(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> [LSPLocation]
    func references(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> [LSPLocation]
    func documentSymbols(in document: TextDocumentIdentifier) async throws -> [SymbolInformation]
    func workspaceSymbols(query: String) async throws -> [SymbolInformation]
    func diagnostics(in document: TextDocumentIdentifier) async throws -> [Diagnostic]
    func signatureHelp(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> SignatureHelp?
    func rename(at position: LSPPosition, to newName: String, in document: TextDocumentIdentifier) async throws -> LSPWorkspaceEdit
}