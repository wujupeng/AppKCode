import SwiftUI
import AppKCodeShared
import AppKCodeDomain

struct GitHistoryView: View {
    let gitService: GitServiceProtocol
    let repoURL: URL?

    @State private var commits: [GitCommitInfo] = []
    @State private var selectedCommit: GitCommitInfo?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
            }
            .padding(8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(commits) { commit in
                        GitCommitRowView(commit: commit, isSelected: selectedCommit?.id == commit.id)
                            .onTapGesture { selectedCommit = commit }
                    }
                }
            }
        }
        .onAppear { loadHistory() }
    }

    private func loadHistory() {
        guard let repoURL = repoURL else { return }
        Task {
            do {
                let result = try await gitService.getLog(at: repoURL, limit: 50, skip: 0)
                await MainActor.run { commits = result }
            } catch {}
        }
    }
}

struct GitCommitRowView: View {
    let commit: GitCommitInfo
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(commit.shortSha)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(commit.messageSubject)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
            }
            HStack(spacing: 8) {
                Text(commit.authorName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(formatDate(commit.authorDate))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}