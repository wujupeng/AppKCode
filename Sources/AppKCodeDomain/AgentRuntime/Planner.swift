import Foundation
import AppKCodeShared

// MARK: - Planner Protocol (TASK-017.1)

public protocol Planner: Sendable {
    func generatePlan(
        userRequest: String,
        session: AgentSessionID,
        availableTools: [ToolSchema],
        context: [ContextItem]
    ) async throws -> ActionPlan
}

// MARK: - Planner Error

public enum PlannerError: Error, Sendable {
    case invalidPlanJSON(String)
    case unknownTool(String)
    case circularDependency
    case missingStep(String)

    public var localizedDescription: String {
        switch self {
        case .invalidPlanJSON(let d): return "Invalid plan JSON: \(d)"
        case .unknownTool(let t): return "Unknown tool: \(t)"
        case .circularDependency: return "Circular dependency detected"
        case .missingStep(let s): return "Missing step: \(s)"
        }
    }
}

// MARK: - AI Planner (TASK-017.2~017.4)

public final class AIPlanner: Planner {
    private let modelProvider: ModelProvider

    public init(modelProvider: ModelProvider) {
        self.modelProvider = modelProvider
    }

    public func generatePlan(
        userRequest: String,
        session: AgentSessionID,
        availableTools: [ToolSchema],
        context: [ContextItem]
    ) async throws -> ActionPlan {
        let prompt = buildPrompt(userRequest: userRequest, availableTools: availableTools)
        let messages: [ChatMessage] = [
            ChatMessage(role: .system, content: "You are an AI agent planner. Generate an action plan as JSON."),
            ChatMessage(role: .user, content: prompt)
        ]
        let request = ChatInferenceRequest(
            messages: messages,
            context: context,
            taskType: .intentRecognition,
            stream: false
        )
        let response = try await modelProvider.infer(request)
        let planJSON = response.message.content
        return try parsePlan(json: planJSON, session: session, availableTools: availableTools)
    }

    private func buildPrompt(userRequest: String, availableTools: [ToolSchema]) -> String {
        let toolList = availableTools.map { schema in
            "  - \(schema.id.rawValue): \(schema.description) [permission: \(schema.permission.rawValue)]"
        }.joined(separator: "\n")
        return """
        User request: \(userRequest)

        Available tools:
        \(toolList)

        Generate an action plan as JSON with this structure:
        {"steps": [{"toolID": "...", "arguments": {...}, "description": "...", "explanation": "...", "priority": "medium", "dependsOn": []}]}

        Priorities: low, medium, high, critical
        """
    }

    private func parsePlan(json: String, session: AgentSessionID, availableTools: [ToolSchema]) throws -> ActionPlan {
        guard let data = json.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stepsArray = raw["steps"] as? [[String: Any]] else {
            throw PlannerError.invalidPlanJSON(json)
        }

        let availableToolIDs = Set(availableTools.map { $0.id })
        var steps: [ActionStep] = []
        var stepIDMap: [String: ActionStepID] = [:]

        for rawStep in stepsArray {
            guard let toolIDStr = rawStep["toolID"] as? String else {
                throw PlannerError.invalidPlanJSON("Missing toolID")
            }
            let toolID = ToolID(toolIDStr)
            guard availableToolIDs.contains(toolID) else {
                throw PlannerError.unknownTool(toolIDStr)
            }
            let stepID = ActionStepID()
            if let idStr = rawStep["id"] as? String {
                stepIDMap[idStr] = stepID
            }
            let description = rawStep["description"] as? String ?? ""
            let explanation = rawStep["explanation"] as? String ?? ""
            let priorityStr = rawStep["priority"] as? String ?? "medium"
            let priority: ActionPriority
            switch priorityStr {
            case "low": priority = .low
            case "high": priority = .high
            case "critical": priority = .critical
            default: priority = .medium
            }
            let argsDict = rawStep["arguments"] as? [String: Any] ?? [:]
            let arguments = ToolArguments(values: parseArguments(argsDict))
            var step = ActionStep(
                id: stepID,
                toolID: toolID,
                arguments: arguments,
                description: description,
                explanation: explanation,
                priority: priority
            )
            if let deps = rawStep["dependsOn"] as? [String] {
                step.dependsOn = deps.compactMap { stepIDMap[$0] }
            }
            steps.append(step)
        }

        try validateNoCycles(steps: steps)
        return ActionPlan(sessionID: session, steps: steps)
    }

    private func parseArguments(_ dict: [String: Any]) -> [String: ToolValue] {
        var result: [String: ToolValue] = [:]
        for (key, value) in dict {
            if let s = value as? String { result[key] = .string(s) }
            else if let i = value as? Int { result[key] = .integer(i) }
            else if let b = value as? Bool { result[key] = .boolean(b) }
        }
        return result
    }

    private func validateNoCycles(steps: [ActionStep]) throws {
        var visited: Set<ActionStepID> = []
        var recStack: Set<ActionStepID> = []
        let stepMap = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0) })
        func dfs(_ id: ActionStepID) throws {
            visited.insert(id)
            recStack.insert(id)
            if let step = stepMap[id] {
                for dep in step.dependsOn {
                    if recStack.contains(dep) { throw PlannerError.circularDependency }
                    if !visited.contains(dep) { try dfs(dep) }
                }
            }
            recStack.remove(id)
        }
        for step in steps where !visited.contains(step.id) {
            try dfs(step.id)
        }
    }
}
