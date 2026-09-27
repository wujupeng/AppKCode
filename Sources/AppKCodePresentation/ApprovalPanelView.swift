import SwiftUI
import AppKCodeShared

struct ApprovalPanelView: View {
    let request: ApprovalRequest
    let onAllow: () -> Void
    let onReject: () -> Void

    @State private var showDiff: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            reasonSection
            affectedFilesSection
            if showDiff { diffPreview }
            actionButtons
        }
        .padding(16)
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    private var header: some View {
        HStack {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundColor(.orange)
                .font(.title2)
            VStack(alignment: .leading) {
                Text("Approval Required")
                    .font(.headline)
                Text("Risk Level: \(riskLevelText)")
                    .font(.caption)
                    .foregroundColor(request.riskLevel == .high ? .red : .orange)
            }
            Spacer()
        }
    }

    private var riskLevelText: String {
        switch request.riskLevel {
        case .high: return "HIGH"
        case .low: return "LOW"
        case .readOnly: return "READ ONLY"
        }
    }

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Operation").font(.caption).foregroundColor(.secondary)
            Text(request.payload.description).font(.system(size: 13))
            Text("Reason").font(.caption).foregroundColor(.secondary)
            Text(request.payload.reason).font(.system(size: 13))
        }
    }

    private var affectedFilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Affected Files (\(request.payload.affectedFiles.count))").font(.caption).foregroundColor(.secondary)
            ForEach(request.payload.affectedFiles, id: \.self) { url in
                Text(url.lastPathComponent)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if !request.payload.affectedFiles.isEmpty {
                Button("Review Diff") { showDiff.toggle() }
                    .buttonStyle(.borderless)
            }
        }
    }

    private var diffPreview: some View {
        Text("Diff preview available in Diff Review panel")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(4)
    }

    private var actionButtons: some View {
        HStack {
            Spacer()
            Button("Reject") { onReject() }
                .buttonStyle(.bordered)
                .tint(.red)

            Button("Allow") { onAllow() }
                .buttonStyle(.borderedProminent)
                .tint(.green)
        }
    }
}