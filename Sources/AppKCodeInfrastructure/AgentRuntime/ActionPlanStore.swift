import Foundation
import AppKCodeShared

// MARK: - Action Plan Store (TASK-009)

public final class ActionPlanStore: @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    private func plansDir(sandboxDir: URL) -> URL {
        sandboxDir.appendingPathComponent("plans")
    }

    private func planFileURL(_ id: ActionPlanID, sandboxDir: URL) -> URL {
        plansDir(sandboxDir: sandboxDir).appendingPathComponent("\(id.rawValue).jsonl")
    }


    public func savePlan(_ plan: ActionPlan, sandboxDir: URL) async throws {
        let dir = plansDir(sandboxDir: sandboxDir)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = planFileURL(plan.id, sandboxDir: sandboxDir)

        let encoder = JSONEncoder()
        var data = try encoder.encode(plan)
        data.append(0x0A)
        try data.write(to: fileURL)
    }

    public func updateStepStatus(
        planID: ActionPlanID,
        stepID: ActionStepID,
        status: ActionStepStatus,
        result: ActionResultSnapshot?,
        sandboxDir: URL
    ) async throws {
        let fileURL = planFileURL(planID, sandboxDir: sandboxDir)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw AgentSessionError.sessionNotFound(AgentSessionID(""))
        }

        let entry = StepStatusUpdate(stepID: stepID, status: status, result: result, updatedAt: ISO8601Timestamp())
        let encoder = JSONEncoder()
        var data = try encoder.encode(entry)
        data.append(0x0A)

        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()
    }

    public func loadPlan(_ id: ActionPlanID, sandboxDir: URL) async throws -> ActionPlan {
        let fileURL = planFileURL(id, sandboxDir: sandboxDir)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw AgentSessionError.sessionNotFound(AgentSessionID(""))
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        guard let firstLine = lines.first else {
            throw AgentSessionError.sessionNotFound(AgentSessionID(""))
        }

        let decoder = JSONDecoder()
        guard let data = String(firstLine).data(using: .utf8),
              var plan = try? decoder.decode(ActionPlan.self, from: data) else {
            throw AppKError.encodingFailed(detail: "action plan")
        }

        if lines.count > 1 {
            var stepMap: [ActionStepID: (ActionStepStatus, ActionResultSnapshot?)] = [:]
            for line in lines.dropFirst() {
                guard let lineData = String(line).data(using: .utf8),
                      let update = try? decoder.decode(StepStatusUpdate.self, from: lineData) else { continue }
                stepMap[update.stepID] = (update.status, update.result)
            }

            plan.steps = plan.steps.map { step in
                var s = step
                if let (newStatus, newResult) = stepMap[step.id] {
                    s.status = newStatus
                    s.result = newResult
                }
                return s
            }
        }

        return plan
    }
}

// MARK: - Step Status Update (internal)

struct StepStatusUpdate: Codable {
    let stepID: ActionStepID
    let status: ActionStepStatus
    let result: ActionResultSnapshot?
    let updatedAt: ISO8601Timestamp
}