import Foundation
import AppKCodeInfrastructure

public class LSPServerAdapter: LanguageService, ObservableObject {
    public let config: LanguageServerConfig
    let lspClient: LSPClient
    let processManager: LSPProcessManager
    let transport: LSPTransport

    @Published public private(set) var serverStatus: LanguageServerStatus = .notStarted
    @Published public private(set) var isAvailable: Bool = false

    private var cachedDiagnostics: [String: [Diagnostic]] = [:]
    private let lock = NSLock()
    private var documentVersions: [String: Int] = [:]

    public init(config: LanguageServerConfig) {
        self.config = config
        self.processManager = LSPProcessManager()
        self.transport = LSPTransport(processManager: processManager)
        self.lspClient = LSPClient(transport: transport, processManager: processManager)

        lspClient.registerNotificationHandler("textDocument/publishDiagnostics") { [weak self] params in
            guard let self = self else { return }
            let diags = LSPResponseParser.parseDiagnostics(params)
            if let uri = params?.value as? [String: AnyCodable],
               let uriStr = uri["uri"]?.value as? String {
                self.lock.lock()
                self.cachedDiagnostics[uriStr] = diags
                self.lock.unlock()
            }
        }
    }

    public func checkAvailability() {
        self.isAvailable = detectExecutable() != nil
    }

    open func detectExecutable() -> String? {
        return nil
    }

    public func initialize(workspaceRoot: URL) async throws {
        guard let execPath = detectExecutable() else {
            throw LSPAdapterError.executableNotFound(config.executablePath)
        }

        serverStatus = .starting
        try processManager.start(executable: execPath, arguments: config.arguments, workingDirectory: workspaceRoot)
        lspClient.startReceiveLoop()

        _ = try await lspClient.initialize(workspaceRoot: workspaceRoot)
        serverStatus = .running
    }

    public func shutdown() async throws {
        try await lspClient.shutdown()
        serverStatus = .stopped
    }

    public func openDocument(_ document: TextDocumentIdentifier, languageId: String, version: Int, text: String) async throws {
        try lspClient.textDocumentDidOpen(uri: document.uri, languageId: languageId, version: version, text: text)
        lock.lock()
        documentVersions[document.uri] = version
        lock.unlock()
    }

    public func closeDocument(_ document: TextDocumentIdentifier) async throws {
        try lspClient.textDocumentDidClose(uri: document.uri)
        lock.lock()
        documentVersions.removeValue(forKey: document.uri)
        cachedDiagnostics.removeValue(forKey: document.uri)
        lock.unlock()
    }

    public func updateDocument(_ document: TextDocumentIdentifier, version: Int, content: String) async throws {
        try lspClient.textDocumentDidChange(uri: document.uri, version: version, text: content)
        lock.lock()
        documentVersions[document.uri] = version
        lock.unlock()
    }

    public func completion(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> [CompletionItem] {
        let result = try await lspClient.textDocumentCompletion(uri: document.uri, line: position.line, character: position.character)
        return LSPResponseParser.parseCompletionItems(result)
    }

    public func hover(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> HoverInfo? {
        let result = try await lspClient.textDocumentHover(uri: document.uri, line: position.line, character: position.character)
        return LSPResponseParser.parseHover(result)
    }

    public func definition(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> [LSPLocation] {
        let result = try await lspClient.textDocumentDefinition(uri: document.uri, line: position.line, character: position.character)
        return LSPResponseParser.parseLocations(result)
    }

    public func declaration(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> [LSPLocation] {
        let result = try await lspClient.textDocumentDeclaration(uri: document.uri, line: position.line, character: position.character)
        return LSPResponseParser.parseLocations(result)
    }

    public func references(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> [LSPLocation] {
        let result = try await lspClient.textDocumentReferences(uri: document.uri, line: position.line, character: position.character)
        return LSPResponseParser.parseLocations(result)
    }

    public func documentSymbols(in document: TextDocumentIdentifier) async throws -> [SymbolInformation] {
        let result = try await lspClient.textDocumentDocumentSymbol(uri: document.uri)
        return LSPResponseParser.parseSymbols(result)
    }

    public func workspaceSymbols(query: String) async throws -> [SymbolInformation] {
        let result = try await lspClient.workspaceSymbol(query: query)
        return LSPResponseParser.parseSymbols(result)
    }

    public func diagnostics(in document: TextDocumentIdentifier) async throws -> [Diagnostic] {
        lock.lock()
        let diags = cachedDiagnostics[document.uri] ?? []
        lock.unlock()
        return diags
    }

    public func signatureHelp(at position: LSPPosition, in document: TextDocumentIdentifier) async throws -> SignatureHelp? {
        let result = try await lspClient.textDocumentSignatureHelp(uri: document.uri, line: position.line, character: position.character)
        return LSPResponseParser.parseSignatureHelp(result)
    }

    public func rename(at position: LSPPosition, to newName: String, in document: TextDocumentIdentifier) async throws -> LSPWorkspaceEdit {
        let result = try await lspClient.textDocumentRename(uri: document.uri, line: position.line, character: position.character, newName: newName)
        return LSPResponseParser.parseWorkspaceEdit(result)
    }
}

public enum LSPAdapterError: Error, Sendable {
    case executableNotFound(String)
    case notInitialized
    case languageNotSupported(String)
}