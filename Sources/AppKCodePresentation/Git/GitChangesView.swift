import SwiftUI
import AppKCodeShared
import AppKCodeDomain

struct GitChangesView: View {
    @ObservedObject var stateManager: GitStateManager
    let gitService: GitServiceProtocol
    let repoURL: URL?

    @State private var selectedFile: GitFileStatusItem?
    @State private var commitMessage: String = ""
    @State private var isCommitting: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Changes")
                    .font(.headline)
                Spacer()
                Button("Stage All") { stageAll() }
                    .buttonStyle(.bordered)
                    .disabled(stateManager.status.files.isEmpty)
            }
            .padding(8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(stateManager.status.files) { file in
                        GitFileRowView(file: file, isSelected: selectedFile?.id == file.id)
                            .onTapGesture { selectedFile = file }
                    }
                }
            }

            Divider()

            VStack(spacing: 4) {
                TextField("Commit message", text: $commitMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                Button("Commit") { commit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(commitMessage.isEmpty || isCommitting)
            }
            .padding(8)
        }
    }

    private func stageAll() {
        guard let repoURL = repoURL else { return }
        Task {
            try? await gitService.stageAll(at: repoURL)
            await stateManager.refresh()
        }
    }

    private func commit() {
        guard let repoURL = repoURL, !commitMessage.isEmpty else { return }
        isCommitting = true
        let message = commitMessage
        Task {
            do {
                _ = try await gitService.commit(message: message, paths: [], at: repoURL)
                await MainActor.run {
                    commitMessage = ""
                    isCommitting = false
                }
                await stateManager.refresh()
            } catch {
                await MainActor.run { isCommitting = false }
            }
        }
    }
}

struct GitFileRowView: View {
    let file: GitFileStatusItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .frame(width: 16)
            Text(file.path)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
            Spacer()
            if file.staged {
                Text("staged")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    private var statusIcon: String {
        switch file.status {
        case .modified: return "pencil"
        case .staged: return "checkmark.circle"
        case .untracked: return "questionmark.circle"
        case .deleted: return "minus.circle"
        case .renamed: return "arrow.right.circle"
        case .typeChanged: return "exclamationmark.circle"
        case .conflicted: return "exclamationmark.triangle"
        }
    }

    private var statusColor: Color {
        switch file.status {
        case .modified: return .yellow
        case .staged: return .green
        case .untracked: return .blue
        case .deleted: return .red
        case .renamed: return .purple
        case .typeChanged: return .orange
        case .conflicted: return .red
        }
    }
}