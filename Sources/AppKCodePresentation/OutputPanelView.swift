import SwiftUI
import AppKCodeShared

struct OutputPanelView: View {
    @State private var outputLines: [String] = []
    @State private var searchText: String = ""
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Build Output").tag(0)
                    Text("Test Output").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                Spacer()
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                Button(action: { outputLines.removeAll() }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Clear Output")
            }
            .padding(4)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(colorForLine(line))
                            .textSelection(.enabled)
                    }
                }
                .padding(4)
            }
        }
    }

    private var filteredLines: [String] {
        if searchText.isEmpty { return outputLines }
        return outputLines.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private func colorForLine(_ line: String) -> Color {
        if line.contains("error:") || line.contains("Error") || line.contains("FAIL") { return .red }
        if line.contains("warning:") || line.contains("Warning") { return .orange }
        if line.contains("passed") || line.contains("PASS") || line.contains("ok") { return .green }
        return .primary
    }

    func append(_ text: String) {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            outputLines.append(String(line))
        }
    }

    func clear() {
        outputLines.removeAll()
    }
}