// TODO(M1): LSP deep integration
import Foundation
import AppKCodeShared

public final class LSPHostService: DomainLSPHost, @unchecked Sendable {
    public init() {}
    public func startServer(language: String, projectRoot: URL) async throws {
        // TODO(M1): implement LSP server process management + JSON-RPC
    }
    public func stopServer(language: String) async throws {
        // TODO(M1): implement LSP server shutdown
    }
}