import SwiftUI
import AppKCodeDomain
import AppKCodeShared

public struct ProblemsPanelView: View {
    @ObservedObject var diagnosticManager: DiagnosticManager
    @State private var buildProblems: [ProblemItem] = []

    public init(diagnosticManager: DiagnosticManager) {
        self.diagnosticManager = diagnosticManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Problems")
                    .font(.headline)
                Spacer()
                Text("\(totalErrors) errors, \(totalWarnings) warnings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            if diagnosticManager.allDiagnosticsFlat().isEmpty && buildProblems.isEmpty {
                Text("No problems detected")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(diagnosticManager.allDiagnosticsFlat().enumerated()), id: \.offset) { _, entry in
                            ProblemRowView(url: entry.url, diagnostic: entry.diagnostic)
                        }
                        ForEach(buildProblems) { problem in
                            BuildProblemRowView(problem: problem)
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    private var totalErrors: Int {
        diagnosticManager.errorCount + buildProblems.filter { $0.severity == .error }.count
    }

    private var totalWarnings: Int {
        diagnosticManager.warningCount + buildProblems.filter { $0.severity == .warning }.count
    }

    public func setBuildProblems(_ problems: [ProblemItem]) {
        buildProblems = problems
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

struct BuildProblemRowView: View {
    let problem: ProblemItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: severityIcon)
                .foregroundColor(severityColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(problem.message)
                    .font(.system(size: 12))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(problem.file)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(problem.locationText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(problem.source.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(NSColor.textBackgroundColor))
        .onTapGesture {
            let url = URL(fileURLWithPath: problem.file)
            NotificationCenter.default.post(name: .appkFileOpenRequested, object: url)
            NotificationCenter.default.post(name: .appkCursorJumpRequested, object: problem.line)
        }
    }

    private var severityIcon: String {
        switch problem.severity {
        case .error: return "xmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .info: return "info.circle"
        case .hint: return "lightbulb"
        }
    }

    private var severityColor: Color {
        switch problem.severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .hint: return .gray
        }
    }
}
