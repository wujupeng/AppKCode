import SwiftUI
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

struct TerminalPanelView: View {
    @State private var terminals: [TerminalTab] = []
    @State private var activeTabIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            if terminals.isEmpty {
                emptyState
            } else if activeTabIndex < terminals.count {
                TerminalView(viewModel: terminals[activeTabIndex].viewModel)
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(terminals.enumerated()), id: \.element.id) { index, tab in
                Button(action: { activeTabIndex = index }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                        Text(tab.title)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(index == activeTabIndex ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: newTerminal) {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
        }
        .padding(4)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No Terminal")
                .foregroundColor(.secondary)
            Button("New Terminal") { newTerminal() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
    }

    private func newTerminal() {
        let tab = TerminalTab()
        terminals.append(tab)
        activeTabIndex = terminals.count - 1
    }
}

struct TerminalTab: Identifiable {
    let id = UUID()
    let title: String
    let viewModel: TerminalViewModel

    init(title: String = "Terminal") {
        self.title = title
        self.viewModel = TerminalViewModel()
    }
}