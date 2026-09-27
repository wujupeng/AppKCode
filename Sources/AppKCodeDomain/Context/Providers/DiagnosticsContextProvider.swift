import Foundation
import AppKCodeShared

public final class DiagnosticsContextProvider: ContextProvider, @unchecked Sendable {
    public let source: ContextSource = .diagnostics
    private let diagnosticsProvider: (@Sendable () async throws -> [(URL, String, Int, String)])?

    public init(diagnosticsProvider: (@Sendable () async throws -> [(URL, String, Int, String)])? = nil) {
        self.diagnosticsProvider = diagnosticsProvider
    }

    public func gather(context: ContextRequest) async throws -> [ContextItem] {
        guard let provider = diagnosticsProvider else {
            return []
        }
        let diagnostics = try await provider()
        guard !diagnostics.isEmpty else {
            return []
        }
        var lines: [String] = []
        for (url, severity, lineNum, message) in diagnostics {
            lines.append("\(severity) \(url.lastPathComponent):\(lineNum) - \(message)")
        }
        let content = lines.joined(separator: "\n")
        let item = ContextItem(
            source: .diagnostics,
            path: nil,
            range: nil,
            content: content,
            metadata: ContextMetadata(
                language: nil,
                fileSize: nil,
                modifiedAt: nil,
                symbolName: nil,
                diagnosticCount: diagnostics.count
            )
        )
        return [item]
    }
}