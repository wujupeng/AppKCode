import SwiftUI
import AppKCodeShared
import AppKCodeDomain

struct GitPanelView: View {
    @ObservedObject var stateManager: GitStateManager
    let gitService: GitServiceProtocol
    let repoURL: URL?

    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Changes").tag(0)
                    Text("Branches").tag(1)
                    Text("History").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                Spacer()
                Button(action: { Task { await stateManager.refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
            .padding(4)

            Divider()

            TabView(selection: $selectedTab) {
                GitChangesView(stateManager: stateManager, gitService: gitService, repoURL: repoURL).tag(0)
                GitBranchView(gitService: gitService, repoURL: repoURL).tag(1)
                GitHistoryView(gitService: gitService, repoURL: repoURL).tag(2)
            }
        }
    }
}