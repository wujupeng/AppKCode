import Foundation
import AppKCodeInfrastructure

@MainActor
public final class LanguageServiceManager: ObservableObject {
    public let registry: LSPServerRegistry
    public let diagnosticManager: DiagnosticManager

    @Published public private(set) var isReady = false
    @Published public private(set) var activeLanguages: Set<String> = []

    public init(workspaceRoot: URL) {
        self.registry = LSPServerRegistry(workspaceRoot: workspaceRoot)
        self.diagnosticManager = DiagnosticManager()
    }

    public func initialize(forLanguage language: String) async throws {
        try await registry.initializeLanguage(language)
        activeLanguages.insert(language)
        isReady = true
    }

    public func initializeForFile(_ url: URL) async throws -> LSPServerAdapter? {
        let language = LanguageIdentifier.identify(url: url)
        guard let adapter = registry.adapter(forLanguage: language) else {
            return nil
        }

        if !activeLanguages.contains(language) {
            try await registry.initializeLanguage(language)
            activeLanguages.insert(language)
            isReady = true
        }

        return adapter
    }

    public func openDocument(url: URL, content: String) async throws -> LSPServerAdapter? {
        guard let adapter = try await initializeForFile(url) else { return nil }
        let doc = TextDocumentIdentifier(url: url)
        let languageId = lspLanguageId(for: url)
        try await adapter.openDocument(doc, languageId: languageId, version: 1, text: content)
        return adapter
    }

    public func closeDocument(url: URL) async throws {
        let language = LanguageIdentifier.identify(url: url)
        guard let adapter = registry.adapter(forLanguage: language) else { return }
        let doc = TextDocumentIdentifier(url: url)
        try await adapter.closeDocument(doc)
    }

    public func updateDocument(url: URL, version: Int, content: String) async throws {
        let language = LanguageIdentifier.identify(url: url)
        guard let adapter = registry.adapter(forLanguage: language) else { return }
        let doc = TextDocumentIdentifier(url: url)
        try await adapter.updateDocument(doc, version: version, content: content)
    }

    public func completion(url: URL, line: Int, character: Int) async throws -> [CompletionItem] {
        guard let adapter = registry.adapter(forURL: url) else { return [] }
        let doc = TextDocumentIdentifier(url: url)
        return try await adapter.completion(at: LSPPosition(line: line, character: character), in: doc)
    }

    public func hover(url: URL, line: Int, character: Int) async throws -> HoverInfo? {
        guard let adapter = registry.adapter(forURL: url) else { return nil }
        let doc = TextDocumentIdentifier(url: url)
        return try await adapter.hover(at: LSPPosition(line: line, character: character), in: doc)
    }

    public func definition(url: URL, line: Int, character: Int) async throws -> [LSPLocation] {
        guard let adapter = registry.adapter(forURL: url) else { return [] }
        let doc = TextDocumentIdentifier(url: url)
        return try await adapter.definition(at: LSPPosition(line: line, character: character), in: doc)
    }

    public func declaration(url: URL, line: Int, character: Int) async throws -> [LSPLocation] {
        guard let adapter = registry.adapter(forURL: url) else { return [] }
        let doc = TextDocumentIdentifier(url: url)
        return try await adapter.declaration(at: LSPPosition(line: line, character: character), in: doc)
    }

    public func references(url: URL, line: Int, character: Int) async throws -> [LSPLocation] {
        guard let adapter = registry.adapter(forURL: url) else { return [] }
        let doc = TextDocumentIdentifier(url: url)
        return try await adapter.references(at: LSPPosition(line: line, character: character), in: doc)
    }

    public func documentSymbols(url: URL) async throws -> [SymbolInformation] {
        guard let adapter = registry.adapter(forURL: url) else { return [] }
        let doc = TextDocumentIdentifier(url: url)
        return try await adapter.documentSymbols(in: doc)
    }

    public func workspaceSymbols(query: String, language: String) async throws -> [SymbolInformation] {
        guard let adapter = registry.adapter(forLanguage: language) else { return [] }
        return try await adapter.workspaceSymbols(query: query)
    }

    public func diagnostics(url: URL) async throws -> [Diagnostic] {
        guard let adapter = registry.adapter(forURL: url) else { return [] }
        let doc = TextDocumentIdentifier(url: url)
        let diags = try await adapter.diagnostics(in: doc)
        diagnosticManager.updateDiagnostics(for: url, diagnostics: diags)
        return diags
    }

    public func signatureHelp(url: URL, line: Int, character: Int) async throws -> SignatureHelp? {
        guard let adapter = registry.adapter(forURL: url) else { return nil }
        let doc = TextDocumentIdentifier(url: url)
        return try await adapter.signatureHelp(at: LSPPosition(line: line, character: character), in: doc)
    }

    public func rename(url: URL, line: Int, character: Int, newName: String) async throws -> LSPWorkspaceEdit {
        guard let adapter = registry.adapter(forURL: url) else { return LSPWorkspaceEdit() }
        let doc = TextDocumentIdentifier(url: url)
        return try await adapter.rename(at: LSPPosition(line: line, character: character), to: newName, in: doc)
    }

    public func shutdownAll() async throws {
        try await registry.shutdownAll()
        activeLanguages.removeAll()
        isReady = false
    }

    private func lspLanguageId(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "c", "h": return "c"
        case "cpp", "cc", "cxx", "hpp": return "cpp"
        case "m": return "objective-c"
        case "mm": return "objective-cpp"
        case "py": return "python"
        case "go": return "go"
        case "js", "mjs": return "javascript"
        case "ts": return "typescript"
        case "jsx": return "javascript"
        case "tsx": return "typescript"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "md", "markdown": return "markdown"
        default: return "plaintext"
        }
    }
}