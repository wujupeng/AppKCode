import SwiftUI
import AppKit

struct IDEShellRootView: View {
    var body: some View {
        IDEShellView()
    }
}

struct IDEShellView: View {
    var body: some View {
        HSplitView {
            ProjectExplorerPlaceholderView()
                .frame(minWidth: 200, idealWidth: 250)

            VSplitView {
                EditorPlaceholderView()
                    .frame(minWidth: 400, minHeight: 300)

                BottomPanelPlaceholderView()
                    .frame(minHeight: 100, idealHeight: 200)
            }

            AgentChatPlaceholderView()
                .frame(minWidth: 300, idealWidth: 350)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProjectExplorerPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Project Explorer")
                .font(.headline)
            Text("Open a folder to browse files")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct EditorPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Editor")
                .font(.headline)
            Text("Open a file to start editing")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct AgentChatPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("AI Agent")
                .font(.headline)
            Text("Ask anything about your code")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct BottomPanelPlaceholderView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TerminalPlaceholderView().tabItem { Label("Terminal", systemImage: "terminal") }.tag(0)
            ProblemsPlaceholderView().tabItem { Label("Problems", systemImage: "exclamationmark.triangle") }.tag(1)
            OutputPlaceholderView().tabItem { Label("Output", systemImage: "text.alignleft") }.tag(2)
            GitPlaceholderView().tabItem { Label("Git", systemImage: "arrow.triangle.branch") }.tag(3)
            TestsPlaceholderView().tabItem { Label("Tests", systemImage: "checkmark.circle") }.tag(4)
        }
    }
}

struct TerminalPlaceholderView: View {
    var body: some View {
        Text("$ Terminal ready")
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
    }
}

struct ProblemsPlaceholderView: View {
    var body: some View { Text("No problems").foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
}

struct OutputPlaceholderView: View {
    var body: some View { Text("No output").foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
}

struct GitPlaceholderView: View {
    var body: some View { Text("Git: not a repository").foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
}

struct TestsPlaceholderView: View {
    var body: some View { Text("No tests run").foregroundColor(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
}