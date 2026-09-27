import SwiftUI
import AppKCodeShared

struct GitStatusBarView: View {
    let gitStatus: GitStatus?
    let isRepo: Bool

    var body: some View {
        HStack(spacing: 6) {
            if !isRepo {
                Text("非 Git 仓库")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else if let status = gitStatus {
                if let branch = status.branchName {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    Text(branch)
                        .font(.system(size: 11, design: .monospaced))
                }
                if status.modifiedCount > 0 || status.stagedCount > 0 || status.untrackedCount > 0 {
                    Text("✱")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("\(status.modifiedCount + status.stagedCount + status.untrackedCount)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.orange)
                }
            } else {
                Text("Git: —")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}