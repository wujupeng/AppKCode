import Foundation
import AppKCodeShared

public final class RipgrepClient: @unchecked Sendable {
    private let processRunner: ProcessRunner

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    public func search(query: String, in directory: URL, options: SearchOptions = SearchOptions()) async throws -> [SearchHit] {
        var args: [String] = ["--line-number", "--no-heading"]
        if options.caseSensitive { args.append("--case-sensitive") }
        else { args.append("-i") }
        if options.wholeWord { args.append("-w") }
        if !options.regex { args.append("--fixed-strings") }
        if let pattern = options.filePattern {
            args.append("--glob")
            args.append(pattern)
        }
        args.append(query)
        args.append(directory.path)

        let result = try await processRunner.run("rg", args: args)
        guard result.exitCode == 0 || result.exitCode == 1 else {
            throw AppKError.toolExecutionFailed(tool: "rg", cause: result.stderr)
        }
        return parseRipgrepOutput(result.stdout)
    }

    public func searchFileNames(query: String, in directory: URL) async throws -> [SearchHit] {
        let args = ["--files", directory.path]
        let result = try await processRunner.run("rg", args: args)
        guard result.exitCode == 0 else {
            throw AppKError.toolExecutionFailed(tool: "rg", cause: result.stderr)
        }
        return result.stdout.split(separator: "\n").compactMap { line in
            let path = String(line)
            if path.lowercased().contains(query.lowercased()) {
                return SearchHit(filePath: path, lineNumber: 0, matchedLine: path)
            }
            return nil
        }
    }

    private func parseRipgrepOutput(_ output: String) -> [SearchHit] {
        var hits: [SearchHit] = []
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 2)
            if parts.count >= 3 {
                let filePath = String(parts[0])
                let lineNumber = Int(parts[1]) ?? 0
                let matchedLine = String(parts[2])
                hits.append(SearchHit(filePath: filePath, lineNumber: lineNumber, matchedLine: matchedLine))
            }
        }
        return hits
    }
}