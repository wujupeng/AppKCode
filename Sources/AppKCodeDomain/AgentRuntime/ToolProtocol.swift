import Foundation
import AppKCodeShared

// MARK: - Validation Result (TASK-011.2)

public enum ValidationResult: Sendable, Equatable {
    case valid
    case invalid(reason: String, missingFields: [String])

    public var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

// MARK: - Agent Tool Protocol (TASK-011.1, H13)

public protocol AgentTool: Sendable {
    var schema: ToolSchema { get }
    func validate(arguments: ToolArguments) -> ValidationResult
    func execute(arguments: ToolArguments, session: AgentSessionID) async throws -> ToolOutput
}