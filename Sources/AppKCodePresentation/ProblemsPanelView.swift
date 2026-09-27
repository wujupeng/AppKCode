import SwiftUI
import AppKCodeDomain

public struct ProblemsPanelView: View {
    @ObservedObject var diagnosticManager: DiagnosticManager

    public init(diagnosticManager: DiagnosticManager) {
        self.diagnosticManager = diagnosticManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Problems")
                    .font(.headline)
                Spacer()
                Text("\(diagnosticManager.errorCount) errors, \(diagnosticManager.warningCount) warnings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            if diagnosticManager.allDiagnosticsFlat().isEmpty {
                Text("No problems detected")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(diagnosticManager.allDiagnosticsFlat().enumerated()), id: \.offset) { _, entry in
                            ProblemRowView(url: entry.url, diagnostic: entry.diagnostic)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct ProblemRowView: View {
    let url: URL
    let diagnostic: Diagnostic

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: severityIcon)
                .foregroundColor(severityColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(diagnostic.message)
                    .font(.system(size: 12))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(url.lastPathComponent)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(diagnostic.range.start.line + 1):\(diagnostic.range.start.character + 1)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if let source = diagnostic.source {
                        Text(source)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(NSColor.textBackgroundColor))
    }

    private var severityIcon: String {
        switch diagnostic.severity {
        case .error: return "xmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .information: return "info.circle"
        case .hint: return "lightbulb"
        }
    }

    private var severityColor: Color {
        switch diagnostic.severity {
        case .error: return .red
        case .warning: return .orange
        case .information: return .blue
        case .hint: return .gray
        }
    }
}