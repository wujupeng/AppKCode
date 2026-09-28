import SwiftUI
import AppKCodeShared

// MARK: - Skill Registry View (TASK-030)

public struct SkillRegistryView: View {
    public let skills: [SkillManifest]
    @State private var selectedSkill: SkillID?

    public init(skills: [SkillManifest] = []) {
        self.skills = skills
    }

    public var body: some View {
        HSplitView {
            List(skills, id: \.id, selection: $selectedSkill) { skill in
                VStack(alignment: .leading) {
                    Text(skill.name).font(.headline)
                    Text("v\(skill.version) — \(skill.description)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 200, idealWidth: 250)

            if let selected = selectedSkill,
               let skill = skills.first(where: { $0.id == selected }) {
                SkillDetailView(skill: skill)
                    .frame(minWidth: 300)
            } else {
                Text("Select a skill to view details")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SkillDetailView: View {
    let skill: SkillManifest

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(skill.name).font(.title2.bold())
                Text(skill.description).foregroundColor(.secondary)

                GroupBox("Execution Policy") {
                    VStack(alignment: .leading) {
                        policyRow("Max Steps", value: "\(skill.executionPolicy.maxSteps)")
                        policyRow("Max Duration", value: "\(skill.executionPolicy.maxDurationSeconds)s")
                        policyRow("Require Approval", value: skill.executionPolicy.requireApproval ? "Yes" : "No")
                        policyRow("Sandboxed", value: skill.executionPolicy.sandboxed ? "Yes" : "No")
                    }
                }

                if let allowedTools = skill.allowedTools, !allowedTools.isEmpty {
                    GroupBox("Allowed Tools") {
                        VStack(alignment: .leading) {
                            ForEach(allowedTools, id: \.rawValue) { tool in
                                Text(tool.rawValue).font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func policyRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.caption.bold()).foregroundColor(.secondary)
            Text(value).font(.system(.caption, design: .monospaced))
        }
    }
}