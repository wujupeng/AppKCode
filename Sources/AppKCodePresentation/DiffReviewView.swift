import SwiftUI
import AppKit
import AppKCodeShared

struct DiffReviewView: View {
    let originalContent: String
    let proposedContent: String
    @State private var acceptedHunks: Set<Int> = []
    @Binding var isResolved: Bool
    let onApply: (String) -> Void

    private var hunks: [DiffHunk] {
        DiffEngine.computeDiff(old: originalContent, new: proposedContent)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(hunks.enumerated()), id: \.offset) { idx, hunk in
                        hunkView(idx: idx, hunk: hunk)
                    }
                }
                .padding(12)
            }
            footer
        }
    }

    private var header: some View {
        HStack {
            Text("Diff Review")
                .font(.headline)
            Spacer()
            Text("\(acceptedHunks.count)/\(hunks.count) hunks accepted")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func hunkView(idx: Int, hunk: DiffHunk) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("@@ -\(hunk.oldStart),\(hunk.oldEnd) +\(hunk.newStart),\(hunk.newEnd) @@")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button(acceptedHunks.contains(idx) ? "Accepted" : "Accept") {
                    if acceptedHunks.contains(idx) {
                        acceptedHunks.remove(idx)
                    } else {
                        acceptedHunks.insert(idx)
                    }
                }
                .buttonStyle(.bordered)
                .tint(acceptedHunks.contains(idx) ? .green : .blue)
            }
            .padding(4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: 0) {
                    Text(line.changeType == .added ? "+" : line.changeType == .removed ? "-" : " ")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(lineColor(line.changeType))
                        .frame(width: 16)
                    Text(line.content)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .background(lineBackground(line.changeType))
            }
        }
        .cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private func lineColor(_ type: DiffChangeType) -> Color {
        switch type {
        case .added: return .green
        case .removed: return .red
        case .context: return .secondary
        }
    }

    private func lineBackground(_ type: DiffChangeType) -> Color {
        switch type {
        case .added: return Color.green.opacity(0.1)
        case .removed: return Color.red.opacity(0.1)
        case .context: return Color.clear
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Reject All") {
                acceptedHunks = []
                isResolved = true
                onApply(originalContent)
            }
            .buttonStyle(.bordered)

            Button("Apply Accepted") {
                let result = DiffEngine.applyHunks(hunks, to: originalContent, acceptedHunkIndices: acceptedHunks)
                isResolved = true
                onApply(result)
            }
            .buttonStyle(.borderedProminent)
            .disabled(acceptedHunks.isEmpty)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}