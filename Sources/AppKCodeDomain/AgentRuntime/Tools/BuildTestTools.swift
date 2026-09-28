import Foundation
import AppKCodeShared

// MARK: - Build Project Tool (TASK-016.1, H12)

public final class BuildProjectTool: AgentTool {
    public let schema: ToolSchema = ToolSchema(
        id: ToolID("build"),
        category: .buildTest,
        permission: .high,
        parameters: [
            ToolParameterSchema(name: "projectRoot", type: .filePath, required: true, description: "Project root directory"),
            ToolParameterSchema(name: "configuration", type: .string, required: false, description: "Build configuration", defaultValue: .string("debug"))
        ],
        returnType: .object,
        description: "Build the project",
        version: "1.0.0"
    )

    private let buildService: BuildService

    public init(buildService: BuildService) {
        self.buildService = buildService
    }

    public func validate(arguments: ToolArguments) -> ValidationResult {
        if arguments.filePath("projectRoot") == nil {
            return .invalid(reason: "Missing required parameter: projectRoot", missingFields: ["projectRoot"])
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        guard let projectRoot = arguments.filePath("projectRoot") else {
            throw AppKError.invalidConfiguration(key: "projectRoot")
        }
        let configStr = arguments.string("configuration") ?? "debug"
        let configuration: BuildConfiguration = configStr == "release" ? .release : .debug

        let stream = buildService.build(tool: .swiftBuild, configuration: configuration, projectRoot: projectRoot)
        var output = ""
        var success = false
        for try await event in stream {
            switch event {
            case .started(let cmd):
                output += "Build started: \(cmd)\n"
            case .stdout(let s):
                output += s + "\n"
            case .stderr(let s):
                output += s + "\n"
            case .problem(let p):
                output += "Problem: \(p.message)\n"
            case .completed(let result):
                success = result.success
                output += "Build \(success ? "succeeded" : "failed")\n"
            }
        }
        return ToolOutput(text: output)
    }
}

// MARK: - Test Runner Tool (TASK-016.2, H12)

public final class TestRunnerTool: AgentTool {
    public let schema: ToolSchema = ToolSchema(
        id: ToolID("test"),
        category: .buildTest,
        permission: .high,
        parameters: [
            ToolParameterSchema(name: "projectRoot", type: .filePath, required: true, description: "Project root directory"),
            ToolParameterSchema(name: "filter", type: .string, required: false, description: "Test filter"),
            ToolParameterSchema(name: "parallel", type: .boolean, required: false, description: "Run tests in parallel", defaultValue: .boolean(true))
        ],
        returnType: .object,
        description: "Run tests",
        version: "1.0.0"
    )

    private let testService: TestService

    public init(testService: TestService) {
        self.testService = testService
    }

    public func validate(arguments: ToolArguments) -> ValidationResult {
        if arguments.filePath("projectRoot") == nil {
            return .invalid(reason: "Missing required parameter: projectRoot", missingFields: ["projectRoot"])
        }
        return .valid
    }

    public func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput {
        guard let projectRoot = arguments.filePath("projectRoot") else {
            throw AppKError.invalidConfiguration(key: "projectRoot")
        }

        let stream = testService.runTests(tool: .swiftBuild, configuration: .debug, projectRoot: projectRoot)
        var output = ""
        var report: TestReport?
        for try await event in stream {
            switch event {
            case .started(let cmd):
                output += "Tests started: \(cmd)\n"
            case .stdout(let s):
                output += s + "\n"
            case .stderr(let s):
                output += s + "\n"
            case .completed(let r):
                report = r
                output += "Passed: \(r.passed), Failed: \(r.failed), Skipped: \(r.skipped)\n"
            }
        }
        var structured: [String: ToolValue]? = nil
        if let r = report {
            structured = [
                "passed": .integer(r.passed),
                "failed": .integer(r.failed),
                "skipped": .integer(r.skipped)
            ]
        }
        return ToolOutput(text: output, structured: structured)
    }
}