import SwiftUI
import AppKCodeShared

// MARK: - Action Plan View (TASK-027)

public struct ActionPlanView: View {
    public let plan: ActionPlan?

    public init(plan: ActionPlan? = nil) {
        self.plan = plan
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Action Plan")
                    .font(.headline)
                Spacer()
            }
            .padding(8)

            Divider()

            if let plan = plan {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(plan.steps.enumerated()), id: \.element.id) { idx, step in
                            ActionStepRowView(step: step, index: idx + 1)
                        }
                    }
                    .padding(8)
                }
            } else {
                Text("No plan generated")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct ActionStepRowView: View {
    let step: ActionStep
    let index: Int
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                statusIcon
                Text("\(index). \(step.description)")
                    .font(.system(.body))
                    .strikethrough(step.status == .cancelled)
                Spacer()
                priorityBadge
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tool: \(step.toolID.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !step.explanation.isEmpty {
                        Text("Explanation: \(step.explanation)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !step.dependsOn.isEmpty {
                        Text("Depends on: \(step.dependsOn.map { $0.rawValue }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let result = step.result {
                        Text("Result: \(result.result.isSuccess ? "Success" : "Failed")")
                            .font(.caption)
                            .foregroundColor(result.result.isSuccess ? .green : .red)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder var statusIcon: some View {
        switch step.status {
        case .pending: Circle().fill(.gray).frame(width: 8, height: 8)
        case .proposing: Circle().fill(.blue).frame(width: 8, height: 8)
        case .awaitingApproval: Circle().fill(.orange).frame(width: 8, height: 8)
        case .approved: Image(systemName: "checkmark.circle").foregroundColor(.green)
        case .rejected: Image(systemName: "xmark.circle").foregroundColor(.red)
        case .executing: ProgressView().scaleEffect(0.5)
        case .succeeded: Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        case .timedOut: Image(systemName: "clock.fill").foregroundColor(.orange)
        case .cancelled: Image(systemName: "minus.circle.fill").foregroundColor(.gray)
        }
    }

    @ViewBuilder var priorityBadge: some View {
        Text(step.priority.rawValue.description)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor.opacity(0.2))
            .cornerRadius(4)
    }

    private var priorityColor: Color {
        switch step.priority {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}