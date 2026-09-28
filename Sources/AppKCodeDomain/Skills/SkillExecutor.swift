import Foundation
import AppKCodeShared

// MARK: - Skill Executor Protocol (TASK-018.1)

public protocol SkillExecutor: Sendable {
    func execute(_ request: SkillInvocationRequest) async throws -> SkillExecutionResult
}

// MARK: - Skill Executor Impl (TASK-018.2~018.5, H16)
// H16: All Tool calls go through M7 ActionExecutor (which includes Authorization + Audit).
// Skill does NOT directly call AgentTool.execute or底层 Service.

public final class SkillExecutorImpl: SkillExecutor, @unchecked Sendable {
    private let registry: SkillRegistry
    private let actionExecutor: ActionExecutor
    private let toolRegistry: ToolRegistry

    public init(registry: SkillRegistry, actionExecutor: ActionExecutor, toolRegistry: ToolRegistry) {
        self.registry = registry
        self.actionExecutor = actionExecutor
        self.toolRegistry = toolRegistry
    }

    public func execute(_ request: SkillInvocationRequest) async throws -> SkillExecutionResult {
        guard let manifest = registry.resolve(request.skillID) else {
            return .failure(error: .invalidInput(reason: "Skill not found"), partialEvidence: [])
        }

        let policy = manifest.executionPolicy
        let startTime = Date()
        var evidenceIDs: [EvidenceRecordID] = []
        var stepCount = 0

        let allowedTools = manifest.allowedTools ?? []
        let allowedCategories = Set(policy.allowedCategories)

        for stepID in generateSteps(for: manifest, input: request.input) {
            stepCount += 1

            if stepCount > policy.maxSteps {
                return .failure(error: .maxStepsExceeded, partialEvidence: evidenceIDs)
            }

            let elapsed = Date().timeIntervalSince(startTime)
            if Int(elapsed) > policy.maxDurationSeconds {
                return .timedOut
            }

            guard let toolSchema = toolRegistry.schema(stepID.toolID) else {
                return .failure(error: .toolNotAllowed(stepID.toolID), partialEvidence: evidenceIDs)
            }

            if !allowedCategories.contains(toolSchema.category) {
                return .failure(error: .toolNotAllowed(stepID.toolID), partialEvidence: evidenceIDs)
            }

            if !allowedTools.isEmpty && !allowedTools.contains(stepID.toolID) {
                return .failure(error: .toolNotAllowed(stepID.toolID), partialEvidence: evidenceIDs)
            }

            let actionStep = ActionStep(
                toolID: stepID.toolID,
                arguments: stepID.arguments,
                description: "Skill step: \(manifest.name)",
                explanation: "Executing skill \(manifest.name) step \(stepCount)"
            )

            let result = try await actionExecutor.execute(actionStep, session: request.sessionID)

            switch result {
            case .success(let success):
                evidenceIDs.append(success.evidenceID)
            case .failure(let failure):
                return .failure(error: .underlyingError(failure.message), partialEvidence: evidenceIDs)
            case .timedOut:
                return .timedOut
            case .cancelled:
                return .cancelled
            }
        }

        return .success(output: request.input, evidence: evidenceIDs)
    }

    private struct SkillStep {
        let toolID: ToolID
        let arguments: ToolArguments
    }

    private func generateSteps(for manifest: SkillManifest, input: AnyCodableValue) -> [SkillStep] {
        return []
    }
}