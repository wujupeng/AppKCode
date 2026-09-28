import SwiftUI
import AppKCodeShared

// MARK: - Authorization Panel View (TASK-028, H12)

public struct AgentAuthorizationPanelView: View {
    public let request: AuthorizationRequest?
    public let onAllow: () -> Void
    public let onReject: () -> Void

    public init(
        request: AuthorizationRequest?,
        onAllow: @escaping () -> Void,
        onReject: @escaping () -> Void
    ) {
        self.request = request
        self.onAllow = onAllow
        self.onReject = onReject
    }

    public var body: some View {
        VStack(spacing: 16) {
            if let request = request {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.shield.fill")
                            .foregroundColor(.orange)
                        Text("Authorization Required")
                            .font(.headline)
                    }

                    GroupBox("Operation") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(request.description)
                                .font(.body)
                            Text("Type: \(operationType(request.operation))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Reason") {
                        Text(request.reason)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Impact Scope") {
                        Text(impactScopeText(request.impactScope))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let diff = request.diffPreview {
                        GroupBox("Diff Preview") {
                            DiffPreviewView(diff: diff)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                HStack(spacing: 16) {
                    Button("Allow", action: onAllow)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    Button("Reject", action: onReject)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    Spacer()
                }
            } else {
                Text("No pending authorization requests")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(minWidth: 400, minHeight: 300)
    }

    private func operationType(_ op: AgentOperationKind) -> String {
        switch op {
        case .fileWrite: return "File Write"
        case .fileDelete: return "File Delete"
        case .commandExec: return "Command Execute"
        case .gitCommit: return "Git Commit"
        case .gitPush: return "Git Push"
        case .gitReset: return "Git Reset"
        case .gitRebase: return "Git Rebase"
        }
    }

    private func impactScopeText(_ scope: ImpactScope) -> String {
        switch scope {
        case .localFile: return "Local file"
        case .localDirectory: return "Local directory"
        case .workspace: return "Workspace"
        case .remote: return "Remote repository"
        case .system: return "System-wide"
        }
    }
}

struct DiffPreviewView: View {
    let diff: DiffPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(diff.filePath.lastPathComponent)
                .font(.caption.bold())
            ForEach(Array(diff.hunks.enumerated()), id: \.offset) { _, hunk in
                ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 4) {
                        Text(line.changeType == .added ? "+" : line.changeType == .removed ? "-" : " ")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(line.changeType == .added ? .green : line.changeType == .removed ? .red : .secondary)
                        Text(line.content)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(line.changeType == .added ? .green : line.changeType == .removed ? .red : .primary)
                    }
                }
            }
        }
    }
}