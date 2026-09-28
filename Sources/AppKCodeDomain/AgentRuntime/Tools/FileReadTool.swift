import Foundation
import AppKCodeShared

// MARK: - File Read Tool (TASK-013.1)

public final class FileReadTool: AgentTool {
    public let schema: ToolSchema = ToolSchema(
        id: ToolID("file.read"),
        category: .fileRead,
        permission: .readOnly,
        parameters: [
            ToolParameterSchema(name: "path", type: .filePath, required: true, description: "Path to the file to read")
        ],
        returnType: .string,
        description: "Read file content",
        version: "1.0.0"
    )

    public init() {}

    public func validate(arguments: ToolArguments) -> ValidationResult {
        if arguments.filePath("path") == nil {
            return .invalid(reason: "Missing required parameter: path", missingFields: ["path"])
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        guard let path = arguments.filePath("path") else {
            throw AppKError.invalidConfiguration(key: "path")
        }
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AppKError.fileNotFound(url: path.path)
        }
        let content = try String(contentsOf: path, encoding: .utf8)
        return ToolOutput(text: content)
    }
}

// MARK: - File Write Tool (TASK-013.2, H12)

public final class FileWriteTool: AgentTool {
    public let schema: ToolSchema = ToolSchema(
        id: ToolID("file.write"),
        category: .fileWrite,
        permission: .high,
        parameters: [
            ToolParameterSchema(name: "path", type: .filePath, required: true, description: "Path to the file to write"),
            ToolParameterSchema(name: "content", type: .string, required: true, description: "Content to write"),
            ToolParameterSchema(name: "createDirectories", type: .boolean, required: false, description: "Create parent directories if needed", defaultValue: .boolean(false))
        ],
        returnType: .string,
        description: "Write content to file",
        version: "1.0.0"
    )

    public init() {}

    public func validate(arguments: ToolArguments) -> ValidationResult {
        var missing: [String] = []
        if arguments.filePath("path") == nil { missing.append("path") }
        if arguments.string("content") == nil { missing.append("content") }
        if !missing.isEmpty {
            return .invalid(reason: "Missing required parameters", missingFields: missing)
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        guard let path = arguments.filePath("path"),
              let content = arguments.string("content") else {
            throw AppKError.invalidConfiguration(key: "path or content")
        }
        let createDirs = arguments.boolean("createDirectories") ?? false

        if createDirs {
            let parent = path.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }

        try content.write(to: path, atomically: true, encoding: .utf8)
        return ToolOutput(text: "File written: \(path.path)")
    }
}

// MARK: - File Delete Tool (TASK-013.4, H12)

public final class FileDeleteTool: AgentTool {
    public let schema: ToolSchema = ToolSchema(
        id: ToolID("file.delete"),
        category: .fileWrite,
        permission: .high,
        parameters: [
            ToolParameterSchema(name: "paths", type: .array(of: .filePath), required: true, description: "Paths to delete"),
            ToolParameterSchema(name: "recursive", type: .boolean, required: false, description: "Delete recursively", defaultValue: .boolean(false))
        ],
        returnType: .string,
        description: "Delete files",
        version: "1.0.0"
    )

    public init() {}

    public func validate(arguments: ToolArguments) -> ValidationResult {
        if arguments.array("paths") == nil {
            return .invalid(reason: "Missing required parameter: paths", missingFields: ["paths"])
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        guard let paths = arguments.array("paths") else {
            throw AppKError.invalidConfiguration(key: "paths")
        }
        let recursive = arguments.boolean("recursive") ?? false

        var deleted: [String] = []
        for value in paths {
            if case .filePath(let url) = value {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    deleted.append(url.path)
                }
            }
        }
        return ToolOutput(text: "Deleted: \(deleted.count) files")
    }
}