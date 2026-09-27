import Foundation

public protocol DiagnosticProvider: PluginCapability {
    func provideDiagnostics(for document: TextDocumentIdentifier) async throws -> [Diagnostic]
}