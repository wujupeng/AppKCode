import SwiftUI
import AppKCodeShared
import AppKCodeDomain
import AppKCodeInfrastructure

struct BuildTestView: View {
    @State private var buildOutput: String = ""
    @State private var testReport: TestReport?
    @State private var isBuilding: Bool = false
    @State private var isTesting: Bool = false
    @State private var selectedTab: Int = 0

    let buildTool: BuildTool?
    let projectRoot: URL?

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            TabView(selection: $selectedTab) {
                buildPanel.tag(0)
                testPanel.tag(1)
            }
        }
    }

    private var tabBar: some View {
        Picker("", selection: $selectedTab) {
            Text("Build").tag(0)
            Text("Tests").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(4)
    }

    private var buildPanel: some View {
        VStack(spacing: 0) {
            HStack {
                if let tool = buildTool {
                    Text("Tool: \(tool.buildCommand)")
                        .font(.system(size: 12, design: .monospaced))
                } else {
                    Text("No build tool detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Build") { runBuild() }
                    .buttonStyle(.borderedProminent)
                    .disabled(buildTool == nil || isBuilding)
            }
            .padding(8)

            ScrollView {
                Text(buildOutput)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(8)
            }
        }
    }

    private var testPanel: some View {
        VStack(spacing: 0) {
            HStack {
                if let tool = buildTool {
                    Text("Tool: \(tool.testCommand)")
                        .font(.system(size: 12, design: .monospaced))
                }
                Spacer()
                Button("Run Tests") { runTests() }
                    .buttonStyle(.borderedProminent)
                    .disabled(buildTool == nil || isTesting)
            }
            .padding(8)

            if let report = testReport {
                testReportView(report)
            } else {
                Text("No tests run")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func testReportView(_ report: TestReport) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Label("\(report.passed)", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                Label("\(report.failed)", systemImage: "xmark.circle.fill").foregroundColor(.red)
                Label("\(report.skipped)", systemImage: "minus.circle.fill").foregroundColor(.gray)
                Spacer()
            }
            .padding(8)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(report.failures, id: \.testName) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.testName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                            Text(failure.reason)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            if let file = failure.file, let line = failure.line {
                                Text("\(file):\(line)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .onTapGesture {
                                        let url = URL(fileURLWithPath: file)
                                        NotificationCenter.default.post(name: .appkFileOpenRequested, object: url)
                                        NotificationCenter.default.post(name: .appkCursorJumpRequested, object: line)
                                    }
                            }
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(4)
                    }
                }
                .padding(8)
            }
        }
    }

    private func runBuild() {
        guard let tool = buildTool, let root = projectRoot else { return }
        isBuilding = true
        buildOutput = "Building…\n"
        Task {
            let service = BuildTestService()
            do {
                let result = try await service.runBuild(tool: tool, at: root)
                await MainActor.run {
                    buildOutput = result.output
                    isBuilding = false
                }
            } catch {
                await MainActor.run {
                    buildOutput = "Build failed: \(error.localizedDescription)"
                    isBuilding = false
                }
            }
        }
    }

    private func runTests() {
        guard let tool = buildTool, let root = projectRoot else { return }
        isTesting = true
        Task {
            let service = BuildTestService()
            do {
                let report = try await service.runTest(tool: tool, at: root)
                await MainActor.run {
                    self.testReport = report
                    self.isTesting = false
                }
            } catch {
                await MainActor.run {
                    self.testReport = TestReport(passed: 0, failed: 1, skipped: 0, failures: [TestFailure(testName: "Error", reason: error.localizedDescription)])
                    self.isTesting = false
                }
            }
        }
    }
}