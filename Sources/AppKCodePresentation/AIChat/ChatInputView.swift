import SwiftUI
import AppKCodeShared

struct ChatInputView: View {
    @State private var inputText: String = ""
    let onSend: (String, Set<ContextSource>) -> Void
    let isStreaming: Bool
    @Binding var selectedSources: Set<ContextSource>

    var body: some View {
        VStack(spacing: 0) {
            contextSourceSelector
            inputBar
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var contextSourceSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ContextSource.allCases, id: \.self) { source in
                    Toggle(sourceLabel(source), isOn: Binding(
                        get: { selectedSources.contains(source) },
                        set: { newValue in
                            if newValue {
                                selectedSources.insert(source)
                            } else {
                                selectedSources.remove(source)
                            }
                        }
                    ))
                    .toggleStyle(.chip)
                    .font(.caption2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask anything… (⌘+Enter)", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .onSubmit { send() }

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.isEmpty || isStreaming)
        }
        .padding(8)
    }

    private func send() {
        guard !inputText.isEmpty, !isStreaming else { return }
        onSend(inputText, selectedSources)
        inputText = ""
    }

    private func sourceLabel(_ source: ContextSource) -> String {
        switch source {
        case .currentFile: return "File"
        case .selectedText: return "Selection"
        case .currentSymbol: return "Symbol"
        case .openTabs: return "Tabs"
        case .workspace: return "Workspace"
        case .diagnostics: return "Diagnostics"
        case .gitDiff: return "Git Diff"
        case .buildTestResults: return "Build/Test"
        }
    }
}

private struct ChipToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 2) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 10))
                configuration.label
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(configuration.isOn ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

private extension ToggleStyle where Self == ChipToggleStyle {
    static var chip: ChipToggleStyle { ChipToggleStyle() }
}