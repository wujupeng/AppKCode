import XCTest
@testable import AppKCodeDomain
import AppKCodeShared

final class ContextProviderTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AppKContextTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_CurrentFileProviderSource() {
        let provider = CurrentFileContextProvider()
        XCTAssertEqual(provider.source, .currentFile)
    }

    func test_CurrentFileProviderGather() async throws {
        let testFile = tempDir.appendingPathComponent("test.swift")
        try "let x = 42".write(to: testFile, atomically: true, encoding: .utf8)
        let provider = CurrentFileContextProvider()
        let request = ContextRequest(projectRoot: tempDir, currentFile: testFile)
        let items = try await provider.gather(context: request)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].source, .currentFile)
        XCTAssertEqual(items[0].content, "let x = 42")
        XCTAssertEqual(items[0].path, testFile)
    }

    func test_CurrentFileProviderNoFile() async throws {
        let provider = CurrentFileContextProvider()
        let request = ContextRequest(projectRoot: tempDir, currentFile: nil)
        let items = try await provider.gather(context: request)
        XCTAssertEqual(items.count, 0)
    }

    func test_SelectedTextProviderSource() {
        let provider = SelectedTextContextProvider()
        XCTAssertEqual(provider.source, .selectedText)
    }

    func test_SelectedTextProviderGather() async throws {
        let testFile = tempDir.appendingPathComponent("test.swift")
        let lines = ["line0", "line1", "line2", "line3", "line4"]
        try lines.joined(separator: "\n").write(to: testFile, atomically: true, encoding: .utf8)
        let provider = SelectedTextContextProvider()
        let request = ContextRequest(
            projectRoot: tempDir,
            currentFile: testFile,
            selection: SourceRange(startLine: 1, endLine: 3)
        )
        let items = try await provider.gather(context: request)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].source, .selectedText)
        XCTAssertTrue(items[0].content.contains("line1"))
        XCTAssertTrue(items[0].content.contains("line3"))
    }

    func test_OpenTabsProviderSource() {
        let provider = OpenTabsContextProvider()
        XCTAssertEqual(provider.source, .openTabs)
    }

    func test_WorkspaceProviderSource() {
        let provider = WorkspaceContextProvider()
        XCTAssertEqual(provider.source, .workspace)
    }

    func test_WorkspaceProviderGather() async throws {
        let file1 = tempDir.appendingPathComponent("file1.swift")
        let file2 = tempDir.appendingPathComponent("file2.swift")
        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        let provider = WorkspaceContextProvider()
        let request = ContextRequest(projectRoot: tempDir)
        let items = try await provider.gather(context: request)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].source, .workspace)
    }

    func test_DiagnosticsProviderSource() {
        let provider = DiagnosticsContextProvider()
        XCTAssertEqual(provider.source, .diagnostics)
    }

    func test_GitDiffProviderSource() {
        let provider = GitDiffContextProvider()
        XCTAssertEqual(provider.source, .gitDiff)
    }

    func test_BuildTestResultsProviderSource() {
        let provider = BuildTestResultsContextProvider()
        XCTAssertEqual(provider.source, .buildTestResults)
    }

    func test_CurrentSymbolProviderSource() {
        let provider = CurrentSymbolContextProvider()
        XCTAssertEqual(provider.source, .currentSymbol)
    }

    func test_ContextAggregatorEnforcesBudget() async throws {
        let budget = ContextBudget(maxTokens: 100, maxItems: 2, truncationStrategy: .head)
        let aggregator = ContextAggregator(providers: [])
        let result = try await aggregator.gather(context: ContextRequest(projectRoot: tempDir, budget: budget))
        XCTAssertTrue(result.count <= 2)
    }

    func test_ContextItemTokenEstimate() {
        let item = ContextItem(source: .currentFile, content: "Hello World")
        XCTAssertEqual(item.tokenEstimate, max(1, "Hello World".count / 4))
    }

    func test_ContextBudgetDefaults() {
        let budget = ContextBudget()
        XCTAssertEqual(budget.maxTokens, 8192)
        XCTAssertEqual(budget.maxItems, 20)
        XCTAssertEqual(budget.truncationStrategy, .headTail)
    }

    func test_ContextSourceAllCases() {
        XCTAssertEqual(ContextSource.allCases.count, 8)
        XCTAssertTrue(ContextSource.allCases.contains(.currentFile))
        XCTAssertTrue(ContextSource.allCases.contains(.buildTestResults))
    }
}
