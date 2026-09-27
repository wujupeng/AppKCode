import Foundation

@MainActor
public final class DiagnosticManager: ObservableObject {
    @Published public private(set) var allDiagnostics: [URL: [Diagnostic]] = [:]
    @Published public private(set) var errorCount: Int = 0
    @Published public private(set) var warningCount: Int = 0
    @Published public private(set) var infoCount: Int = 0

    public init() {}

    public func updateDiagnostics(for url: URL, diagnostics: [Diagnostic]) {
        allDiagnostics[url] = diagnostics
        recalculateCounts()
    }

    public func clearDiagnostics(for url: URL) {
        allDiagnostics.removeValue(forKey: url)
        recalculateCounts()
    }

    public func clearAll() {
        allDiagnostics.removeAll()
        errorCount = 0
        warningCount = 0
        infoCount = 0
    }

    public func diagnostics(for url: URL) -> [Diagnostic] {
        allDiagnostics[url] ?? []
    }

    public func allDiagnosticsFlat() -> [(url: URL, diagnostic: Diagnostic)] {
        var result: [(URL, Diagnostic)] = []
        for (url, diags) in allDiagnostics {
            for diag in diags {
                result.append((url, diag))
            }
        }
        return result.sorted { a, b in
            if a.diagnostic.severity.rawValue != b.diagnostic.severity.rawValue {
                return a.diagnostic.severity.rawValue < b.diagnostic.severity.rawValue
            }
            return a.url.path < b.url.path
        }
    }

    private func recalculateCounts() {
        var errors = 0
        var warnings = 0
        var infos = 0
        for (_, diags) in allDiagnostics {
            for diag in diags {
                switch diag.severity {
                case .error: errors += 1
                case .warning: warnings += 1
                case .information, .hint: infos += 1
                }
            }
        }
        errorCount = errors
        warningCount = warnings
        infoCount = infos
    }
}