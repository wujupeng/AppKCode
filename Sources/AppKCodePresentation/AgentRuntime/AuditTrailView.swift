import SwiftUI
import AppKCodeShared

// MARK: - Audit Trail View (TASK-029, H14)

public struct AuditTrailView: View {
    public let records: [AgentAuditRecord]

    public init(records: [AgentAuditRecord] = []) {
        self.records = records
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Audit Trail")
                    .font(.headline)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
            }
            .padding(8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(records, id: \.id) { record in
                        AuditRecordRowView(record: record)
                    }
                }
                .padding(8)
            }
        }
    }
}

struct AuditRecordRowView: View {
    let record: AgentAuditRecord
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                resultIcon
                Text(record.timestamp.rawValue.prefix(19))
                    .font(.system(.caption, design: .monospaced))
                Text(record.tool.rawValue)
                    .font(.caption.bold())
                Spacer()
                Text(record.sha256.prefix(8))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    auditField("Session", value: record.sessionID.rawValue)
                    auditField("Tool", value: record.tool.rawValue)
                    auditField("Target", value: targetText(record.target))
                    auditField("Approval", value: approvalText(record.approval))
                    auditField("Result", value: resultText(record.result))
                    if let error = record.error {
                        auditField("Error", value: error)
                    }
                    auditField("SHA-256", value: record.sha256)
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder var resultIcon: some View {
        switch record.result {
        case .success: Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .failure: Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        case .timedOut: Image(systemName: "clock.fill").foregroundColor(.orange)
        case .cancelled: Image(systemName: "minus.circle.fill").foregroundColor(.gray)
        }
    }

    private func auditField(_ label: String, value: String) -> some View {
        HStack {
            Text("\(label):").font(.caption.bold()).foregroundColor(.secondary)
            Text(value).font(.system(.caption, design: .monospaced))
        }
    }

    private func targetText(_ target: AuditTarget) -> String {
        switch target {
        case .filePath(let u): return u.path
        case .command(let c): return c
        case .gitRemote(let r): return r
        case .buildTarget(let t): return t
        case .testTarget(let t): return t
        case .none: return "none"
        }
    }

    private func approvalText(_ decision: AuthorizationDecision) -> String {
        switch decision {
        case .allowed: return "Allowed"
        case .rejected: return "Rejected"
        case .timeout: return "Timeout"
        }
    }

    private func resultText(_ result: AuditResultSummary) -> String {
        switch result {
        case .success: return "Success"
        case .failure(let code, let msg): return "Failure(\(code)): \(msg)"
        case .timedOut: return "Timed Out"
        case .cancelled: return "Cancelled"
        }
    }
}