import SwiftUI
import AppKCodeShared
import AppKCodeDomain

struct GitBranchView: View {
    let gitService: GitServiceProtocol
    let repoURL: URL?

    @State private var branches: [GitBranchInfo] = []
    @State private var newBranchName: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Branches")
                    .font(.headline)
                Spacer()
                TextField("New branch", text: $newBranchName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Button("Create") { createBranch() }
                    .buttonStyle(.bordered)
                    .disabled(newBranchName.isEmpty)
            }
            .padding(8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(branches) { branch in
                        GitBranchRowView(branch: branch, gitService: gitService, repoURL: repoURL, onCheckout: { loadBranches() })
                    }
                }
            }
        }
        .onAppear { loadBranches() }
    }

    private func loadBranches() {
        guard let repoURL = repoURL else { return }
        isLoading = true
        Task {
            do {
                let result = try await gitService.listBranches(at: repoURL)
                await MainActor.run {
                    branches = result
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func createBranch() {
        guard let repoURL = repoURL, !newBranchName.isEmpty else { return }
        Task {
            try? await gitService.createBranch(name: newBranchName, at: repoURL, from: nil)
            await MainActor.run { newBranchName = "" }
            loadBranches()
        }
    }
}

struct GitBranchRowView: View {
    let branch: GitBranchInfo
    let gitService: GitServiceProtocol
    let repoURL: URL?
    let onCheckout: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: branch.isCurrent ? "checkmark.circle.fill" : "circle")
                .foregroundColor(branch.isCurrent ? .green : .secondary)
            Text(branch.name)
                .font(.system(size: 12, design: .monospaced))
            if branch.isRemote {
                Text("remote")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !branch.isCurrent && !branch.isRemote {
                Button("Checkout") { checkout() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func checkout() {
        guard let repoURL = repoURL else { return }
        Task {
            try? await gitService.checkout(branch: branch.name, at: repoURL)
            onCheckout()
        }
    }
}