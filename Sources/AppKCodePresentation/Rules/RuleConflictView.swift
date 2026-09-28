import SwiftUI
import AppKCodeShared

// MARK: - Rule Conflict View (TASK-031.4)

public struct RuleConflictView: View {
    public let conflicts: [RuleConflict]

    public init(conflicts: [RuleConflict] = []) {
        self.conflicts = conflicts
    }

    public var body: some View {
        VStack {
            if conflicts.isEmpty {
                Text("No rule conflicts detected")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(conflicts, id: \.description) { conflict in
                    VStack(alignment: .leading) {
                        HStack {
                            conflictTypeIcon(conflict.conflictType)
                            Text(conflictTypeText(conflict.conflictType))
                                .font(.headline)
                        }
                        Text(conflict.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Rules: \(conflict.rule1.rawValue) vs \(conflict.rule2.rawValue)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func conflictTypeIcon(_ type: RuleConflictType) -> some View {
        switch type {
        case .contradictoryInstruction:
            return Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
        case .sameTargetDifferentEnforcement:
            return Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
        case .priorityCycle:
            return Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.purple)
        }
    }

    private func conflictTypeText(_ type: RuleConflictType) -> String {
        switch type {
        case .contradictoryInstruction: return "Contradictory Instruction"
        case .sameTargetDifferentEnforcement: return "Different Enforcement at Same Priority"
        case .priorityCycle: return "Priority Cycle"
        }
    }
}