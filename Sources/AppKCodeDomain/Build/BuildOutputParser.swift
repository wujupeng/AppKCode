import Foundation
import AppKCodeShared

public final class BuildOutputParser: @unchecked Sendable {
    public init() {}

    public func parse(_ output: String, source: ProblemSource = .build) -> [ProblemItem] {
        var problems: [ProblemItem] = []
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let lineStr = String(line)
            if let problem = parseLine(lineStr, source: source) {
                problems.append(problem)
            }
        }
        return problems
    }

    private func parseLine(_ line: String, source: ProblemSource) -> ProblemItem? {
        if let p = parseSwiftCompilerLine(line, source: source) { return p }
        if let p = parseClangCompilerLine(line, source: source) { return p }
        if let p = parseGoCompilerLine(line, source: source) { return p }
        if let p = parseCMakeLine(line, source: source) { return p }
        return nil
    }

    private func parseSwiftCompilerLine(_ line: String, source: ProblemSource) -> ProblemItem? {
        let pattern = #"/[^:]+\.swift:\d+:\d+: (error|warning|note): (.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }

        let fileRange = match.range(at: 0)
        guard let _ = Range(fileRange, in: line) else { return nil }

        let parts = line.components(separatedBy: ":")
        guard parts.count >= 4 else { return nil }

        let file = parts[0]
        guard let lineNum = Int(parts[1]) else { return nil }
        guard let col = Int(parts[2]) else { return nil }

        let rest = parts[3...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
        let severity: ProblemSeverity
        let message: String

        if rest.hasPrefix("error:") {
            severity = .error
            message = String(rest.dropFirst("error:".count)).trimmingCharacters(in: .whitespaces)
        } else if rest.hasPrefix("warning:") {
            severity = .warning
            message = String(rest.dropFirst("warning:".count)).trimmingCharacters(in: .whitespaces)
        } else if rest.hasPrefix("note:") {
            severity = .info
            message = String(rest.dropFirst("note:".count)).trimmingCharacters(in: .whitespaces)
        } else {
            return nil
        }

        return ProblemItem(file: file, line: lineNum, column: col, severity: severity, message: message, source: source)
    }

    private func parseClangCompilerLine(_ line: String, source: ProblemSource) -> ProblemItem? {
        let pattern = #"/[^:]+:\d+:\d+: (error|warning|note): (.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }

        let fullRange = match.range(at: 0)
        guard let _ = Range(fullRange, in: line) else { return nil }

        let parts = line.components(separatedBy: ":")
        guard parts.count >= 4 else { return nil }

        let file = parts[0]
        guard let lineNum = Int(parts[1]) else { return nil }
        guard let col = Int(parts[2]) else { return nil }

        let rest = parts[3...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
        let severity: ProblemSeverity
        let message: String

        if rest.hasPrefix("error:") {
            severity = .error
            message = String(rest.dropFirst("error:".count)).trimmingCharacters(in: .whitespaces)
        } else if rest.hasPrefix("warning:") {
            severity = .warning
            message = String(rest.dropFirst("warning:".count)).trimmingCharacters(in: .whitespaces)
        } else if rest.hasPrefix("note:") {
            severity = .info
            message = String(rest.dropFirst("note:".count)).trimmingCharacters(in: .whitespaces)
        } else {
            return nil
        }

        return ProblemItem(file: file, line: lineNum, column: col, severity: severity, message: message, source: source)
    }

    private func parseGoCompilerLine(_ line: String, source: ProblemSource) -> ProblemItem? {
        let pattern = #"/[^:]+\.go:\d+:\d+: (.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: range) else { return nil }

        let fullRange = match.range(at: 0)
        guard let _ = Range(fullRange, in: line) else { return nil }

        let parts = line.components(separatedBy: ":")
        guard parts.count >= 4 else { return nil }

        let file = parts[0]
        guard let lineNum = Int(parts[1]) else { return nil }
        guard let col = Int(parts[2]) else { return nil }
        let message = parts[3...].joined(separator: ":").trimmingCharacters(in: .whitespaces)

        return ProblemItem(file: file, line: lineNum, column: col, severity: .error, message: message, source: source)
    }

    private func parseCMakeLine(_ line: String, source: ProblemSource) -> ProblemItem? {
        if line.contains("CMake Error") {
            return ProblemItem(file: "CMakeLists.txt", line: 0, severity: .error, message: line, source: source)
        }
        if line.contains("CMake Warning") {
            return ProblemItem(file: "CMakeLists.txt", line: 0, severity: .warning, message: line, source: source)
        }
        return nil
    }
}