import SwiftUI
import AppKCodeShared
import AppKCodeDomain

struct GitStatusView: View {
    @ObservedObject var stateManager: GitStateManager

    var body: some View {
        HStack(spacing: 8) {
            if stateManager.status.isRepository {
                if let branch = stateManager.currentBranch {
                    Image(systemName: "arrow.triangle.branch")
                    Text(branch)
                        .font(.system(size: 12, design: .monospaced))
                }
                if stateManager.status.aheadCount > 0 {
                    Image(systemName: "arrow.up")
                    Text("\(stateManager.status.aheadCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
                if stateManager.status.behindCount > 0 {
                    Image(systemName: "arrow.down")
                    Text("\(stateManager.status.behindCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                if stateManager.modifiedCount > 0 {
                    Text("M\(stateManager.modifiedCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow)
                }
                if stateManager.stagedCount > 0 {
                    Text("S\(stateManager.stagedCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
                if stateManager.untrackedCount > 0 {
                    Text("U\(stateManager.untrackedCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
            } else {
                Text("Not a git repository")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}