// TODO(M1): embedding + depgraph - Codebase Understanding deep integration
import Foundation
import AppKCodeShared

public final class CodebaseIndexService: DomainCodebaseIndex, @unchecked Sendable {
    public init() {}
    public func indexProject(root: URL) async throws {
        // TODO(M1): implement file index + symbol index + AST + embedding + depgraph
    }
    public func query(_ query: String) async throws -> [SearchHit] {
        // TODO(M1): implement semantic query
        return []
    }
}