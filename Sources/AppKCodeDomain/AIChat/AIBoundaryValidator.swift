import Foundation
import AppKCodeShared

public final class AIBoundaryValidator: @unchecked Sendable {
    public init() {}

    public func validate(capability: AICapability) -> AIBoundaryDecision {
        return AIBoundaryDecision(
            allowed: [capability],
            prohibited: [],
            reason: "Capability '\(capability.rawValue)' is allowed under H9 AI Approval Boundary."
        )
    }

    public func validate(action: AIProhibitedAction) -> AIBoundaryDecision {
        return AIBoundaryDecision(
            allowed: [],
            prohibited: [action],
            reason: "Action '\(action.rawValue)' is prohibited under H9 AI Approval Boundary. This operation requires Agent Runtime + Authorization support."
        )
    }

    public func checkResponse(_ content: String) -> [AIProhibitedAction] {
        var detected: [AIProhibitedAction] = []
        let lower = content.lowercased()
        if lower.contains("write file") || lower.contains("create file") || lower.contains("modify file") || lower.contains("delete file") {
            detected.append(.writeFile)
        }
        if lower.contains("execute command") || lower.contains("run command") || lower.contains("shell exec") {
            detected.append(.executeCommand)
        }
        if lower.contains("git commit") {
            detected.append(.gitCommit)
        }
        if lower.contains("git push") {
            detected.append(.gitPush)
        }
        return detected
    }

    public func isAllowed(_ capability: AICapability) -> Bool {
        return true
    }

    public func isProhibited(_ action: AIProhibitedAction) -> Bool {
        return true
    }
}