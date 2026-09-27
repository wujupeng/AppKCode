import Foundation
import AppKCodeShared

public final class ProblemMapper: @unchecked Sendable {
    private let parser: BuildOutputParser

    public init(parser: BuildOutputParser = BuildOutputParser()) {
        self.parser = parser
    }

    public func mapBuildOutput(_ output: String) -> [ProblemItem] {
        parser.parse(output, source: .build)
    }

    public func merge(problems: [ProblemItem], diagnostics: [ProblemItem]) -> [ProblemItem] {
        var seen = Set<String>()
        var result: [ProblemItem] = []
        for item in problems + diagnostics {
            let key = "\(item.file):\(item.line):\(item.column):\(item.message)"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(item)
            }
        }
        return result.sorted { $0.severity < $1.severity }
    }
}