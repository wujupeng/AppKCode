import Foundation
import AppKCodeShared

public final class ToolchainDetector: @unchecked Sendable {
    private let processRunner: ProcessRunner

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    public func detectAll() async -> [ToolchainInfo] {
        var results: [ToolchainInfo] = []
        for kind in ToolchainKind.allCases {
            let info = await detect(kind: kind)
            results.append(info)
        }
        return results
    }

    public func detect(kind: ToolchainKind) async -> ToolchainInfo {
        let isInstalled = await processRunner.isInstalled(kind.executableName)
        if !isInstalled {
            return ToolchainInfo(kind: kind, path: "", version: "", isAvailable: false)
        }

        let whichResult = try? await processRunner.run(Command(executable: "which", arguments: [kind.executableName]))
        let path = whichResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let versionCmd = Command(executable: kind.executableName, arguments: kind.versionArguments)
        let versionResult = try? await processRunner.run(versionCmd)
        let version = parseVersion(from: versionResult?.stdout ?? versionResult?.stderr ?? "", kind: kind)

        return ToolchainInfo(kind: kind, path: path, version: version, isAvailable: true)
    }

    public func detectForLanguage(_ language: String) async -> ToolchainInfo? {
        let kind: ToolchainKind
        switch language.lowercased() {
        case "swift": kind = .swift
        case "c", "cpp", "c++", "objective-c", "objc": kind = .clang
        case "go", "golang": kind = .go
        case "python", "py": kind = .python
        case "javascript", "js", "typescript", "ts": kind = .node
        default: return nil
        }
        let info = await detect(kind: kind)
        return info.isAvailable ? info : nil
    }

    private func parseVersion(from output: String, kind: ToolchainKind) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .swift, .clang:
            if let firstLine = trimmed.split(separator: "\n").first {
                return String(firstLine)
            }
            return trimmed
        case .go:
            if trimmed.hasPrefix("go version ") {
                return String(trimmed.dropFirst("go version ".count))
            }
            return trimmed
        case .python:
            if trimmed.hasPrefix("Python ") {
                return String(trimmed.dropFirst("Python ".count))
            }
            return trimmed
        case .node:
            if trimmed.hasPrefix("v") {
                return String(trimmed.dropFirst())
            }
            return trimmed
        case .make:
            if let firstLine = trimmed.split(separator: "\n").first {
                return String(firstLine)
            }
            return trimmed
        case .cmake:
            if let firstLine = trimmed.split(separator: "\n").first {
                return String(firstLine)
            }
            return trimmed
        }
    }
}