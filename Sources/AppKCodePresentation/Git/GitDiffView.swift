import SwiftUI
import AppKCodeShared

struct GitDiffView: View {
    let fileDiff: GitFileDiff?

    var body: some View {
        if let diff = fileDiff {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(diff.oldPath.isEmpty ? diff.newPath : "\(diff.oldPath) → \(diff.newPath)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("+\(diff.addedLinesCount) -\(diff.deletedLinesCount)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(8)

                    ForEach(diff.hunks) { hunk in
                        GitHunkView(hunk: hunk)
                    }
                }
            }
        } else {
            Text("No diff")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct GitHunkView: View {
    let hunk: GitDiffHunk

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("@@ -\(hunk.oldStartLine),\(hunk.oldLineCount) +\(hunk.newStartLine),\(hunk.newLineCount) @@")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)

            ForEach(hunk.lines) { line in
                GitDiffLineView(line: line)
            }
        }
    }
}

struct GitDiffLineView: View {
    let line: GitDiffLine

    var body: some View {
        HStack(spacing: 0) {
            Text(linePrefix)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(line.content)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(textColor)
            Spacer()
        }
        .padding(.horizontal, 8)
        .background(backgroundColor)
    }

    private var linePrefix: String {
        switch line.kind {
        case .context: return " "
        case .added: return "+"
        case .deleted: return "-"
        }
    }

    private var textColor: Color {
        switch line.kind {
        case .context: return .primary
        case .added: return .green
        case .deleted: return .red
        }
    }

    private var backgroundColor: Color {
        switch line.kind {
        case .context: return Color.clear
        case .added: return Color.green.opacity(0.1)
        case .deleted: return Color.red.opacity(0.1)
        }
    }
}