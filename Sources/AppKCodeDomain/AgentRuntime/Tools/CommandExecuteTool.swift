import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - Command Execute Tool (TASK-014, H7/H12)

public final class CommandExecuteTool: AgentTool {
    public let schema: ToolSchema = ToolSchema(
        id: ToolID("command.execute"),
        category: .command,
        permission: .high,
        parameters: [
            ToolParameterSchema(name: "command", type: .string, required: true, description: "Command to execute"),
            ToolParameterSchema(name: "args", type: .array(of: .string), required: false, description: "Command arguments"),
            ToolParameterSchema(name: "workingDirectory", type: .filePath, required: false, description: "Working directory"),
            ToolParameterSchema(name: "timeout", type: .integer, required: false, description: "Timeout in seconds", defaultValue: .integer(30))
        ],
        returnType: .string,
        description: "Execute a shell command",
        version: "1.0.0"
    )

    private let processRunner: ProcessRunner
    private let dangerousPatterns: [String] = [
        "rm -rf /", "rm -rf ~", "rm -rf /*", "mkfs", "dd if=", ":(){:|:&};:",
        "chmod -R 777 /", "sudo rm", "> /dev/sda", "fork bomb"
    ]

    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }

    public func validate(arguments: ToolArguments) -> ValidationResult {
        if arguments.string("command") == nil {
            return .invalid(reason: "Missing required parameter: command", missingFields: ["command"])
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        guard let command = arguments.string("command") else {
            throw AppKError.invalidConfiguration(key: "command")
        }

        let fullCommand = command + " " + (arguments.array("args")?.compactMap { if case .string(let s) = $0 { return s } else { return nil } }.joined(separator: " ") ?? "")
        for pattern in dangerousPatterns {
            if fullCommand.contains(pattern) {
                throw AppKError.toolExecutionFailed(tool: "command.execute", cause: "Dangerous command blocked (H7): \(pattern)")
            }
        }

        let args: [String] = arguments.array("args")?.compactMap { v -> String? in
            if case .string(let s) = v { return s } else { return nil }
        } ?? []
        let workingDir = arguments.filePath("workingDirectory")
        let timeout = arguments.integer("timeout") ?? 30

        let result = try await processRunner.run(
            command,
            args: args,
            in: workingDir
        )

        let output = "stdout: \(result.stdout)\nstderr: \(result.stderr)\nexitCode: \(result.exitCode)"
        return ToolOutput(text: output)
    }
}