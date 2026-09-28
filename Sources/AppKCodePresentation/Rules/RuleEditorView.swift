import SwiftUI
import AppKCodeShared

// MARK: - Rule Editor View (TASK-031)

public struct RuleEditorView: View {
    public let rules: [Rule]
    @State private var selectedRule: RuleID?

    public init(rules: [Rule] = []) {
        self.rules = rules
    }

    public var body: some View {
        HSplitView {
            List(rules, id: \.id, selection: $selectedRule) { rule in
                HStack {
                    VStack(alignment: .leading) {
                        Text(rule.name).font(.body)
                        Text("\(rule.scope.rawValue) · priority \(rule.priority.value)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    enforcementBadge(rule.enforcement)
                }
            }
            .frame(minWidth: 250, idealWidth: 300)

            if let selected = selectedRule,
               let rule = rules.first(where: { $0.id == selected }) {
                RuleDetailView(rule: rule)
                    .frame(minWidth: 300)
            } else {
                Text("Select a rule to view details")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func enforcementBadge(_ enforcement: RuleEnforcement) -> some View {
        switch enforcement {
        case .block:
            return Text("Block").foregroundColor(.red).font(.caption.bold())
        case .warn:
            return Text("Warn").foregroundColor(.orange).font(.caption.bold())
        case .info:
            return Text("Info").foregroundColor(.blue).font(.caption.bold())
        }
    }
}

struct RuleDetailView: View {
    let rule: Rule

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(rule.name).font(.title2.bold())

                GroupBox("Condition") {
                    VStack(alignment: .leading) {
                        Text("Target: \(targetText(rule.condition.target))")
                            .font(.system(.caption, design: .monospaced))
                        Text("Matcher: \(matcherText(rule.condition.matcher))")
                            .font(.system(.caption, design: .monospaced))
                    }
                }

                GroupBox("Instruction") {
                    VStack(alignment: .leading) {
                        Text(rule.instruction.description)
                        if rule.instruction.denyExecution {
                            Text("Deny Execution: Yes").foregroundColor(.red).font(.caption)
                        }
                        if rule.instruction.requireApproval {
                            Text("Require Approval: Yes").font(.caption)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func targetText(_ target: RuleTarget) -> String {
        switch target {
        case .toolID(let id): return "toolID(\(id.rawValue))"
        case .toolCategory(let c): return "toolCategory(\(c.rawValue))"
        case .operationKind(let k): return "operationKind(\(k))"
        case .all: return "all"
        }
    }

    private func matcherText(_ matcher: RuleMatcher) -> String {
        switch matcher {
        case .equals(let v): return "equals(\(v))"
        case .contains(let v): return "contains(\(v))"
        case .regex(let v): return "regex(\(v))"
        case .always: return "always"
        }
    }
}