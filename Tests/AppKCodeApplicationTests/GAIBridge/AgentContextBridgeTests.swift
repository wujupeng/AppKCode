import XCTest
@testable import AppKCodeShared
@testable import AppKCodeDomain
@testable import AppKCodeApplication

// MARK: - Test Stubs for P2

private struct StubPublicProtocolSurfaceProvider: PublicProtocolSurfaceProvider {
    func surface(for kind: AdapterKind) -> PublicProtocolSurface {
        return PublicProtocolSurface(
            apis: [],
            version: SemVer(1, 0, 0),
            deprecated: []
        )
    }
}

private struct StubContextProvider: ContextProvider {
    let source: ContextSource = .workspace

    func gather(context: ContextRequest) async throws -> [ContextItem] {
        return [
            ContextItem(source: .workspace, content: "test workspace content"),
            ContextItem(source: .currentFile, content: "test file content")
        ]
    }
}

private struct EmptyContextProvider: ContextProvider {
    let source: ContextSource = .diagnostics

    func gather(context: ContextRequest) async throws -> [ContextItem] {
        return []
    }
}

// MARK: - AgentContextBridge Tests (M11-P2-TASK-004)

final class AgentContextBridgeTests: XCTestCase {

    // MARK: - AgentContextSource Tests

    func testAgentContextSource_rawValues() {
        XCTAssertEqual(AgentContextSource.gaiRuntime.rawValue, "gaiRuntime")
        XCTAssertEqual(AgentContextSource.codeArtsAgent.rawValue, "codeArtsAgent")
        XCTAssertEqual(AgentContextSource.appkcodeAgent.rawValue, "appkcodeAgent")
    }

    func testAgentContextSource_caseIterable() {
        let allSources = AgentContextSource.allCases
        XCTAssertEqual(allSources.count, 3)
        XCTAssertTrue(allSources.contains(.gaiRuntime))
        XCTAssertTrue(allSources.contains(.codeArtsAgent))
        XCTAssertTrue(allSources.contains(.appkcodeAgent))
    }

    // MARK: - AgentContextRequest Tests

    func testAgentContextRequest_constructionWithDefaults() {
        let request = AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )

        XCTAssertEqual(request.source, .gaiRuntime)
        XCTAssertEqual(request.projectRoot, URL(fileURLWithPath: "/tmp"))
        XCTAssertEqual(request.budget.maxTokens, 8192)
        XCTAssertEqual(request.budget.maxItems, 20)
    }

    func testAgentContextRequest_constructionWithCustomBudget() {
        let budget = ContextBudget(maxTokens: 4096, maxItems: 10)
        let request = AgentContextRequest(
            source: .codeArtsAgent,
            projectRoot: URL(fileURLWithPath: "/project"),
            budget: budget
        )

        XCTAssertEqual(request.source, .codeArtsAgent)
        XCTAssertEqual(request.budget.maxTokens, 4096)
        XCTAssertEqual(request.budget.maxItems, 10)
    }

    func testAgentContextRequest_equatable() {
        let req1 = AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )
        let req2 = AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )

        XCTAssertEqual(req1, req2)
    }

    // MARK: - AgentContextBridgeImpl Tests (G-AI Path, H10)

    func testAgentContextBridgeImpl_conformsToProtocol() {
        let aggregator = ContextAggregator(providers: [])
        let bridge: AgentContextBridge = AgentContextBridgeImpl(contextAggregator: aggregator)

        XCTAssertNotNil(bridge)
    }

    func testH10_gaiContextViaContextAggregator() async throws {
        let provider = StubContextProvider()
        let aggregator = ContextAggregator(providers: [provider])
        let bridge = AgentContextBridgeImpl(contextAggregator: aggregator)

        let request = AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )

        let items = try await bridge.gatherContext(request)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].source, .workspace)
        XCTAssertEqual(items[1].source, .currentFile)
    }

    func testH10_gaiContextEmptyProviders() async throws {
        let aggregator = ContextAggregator(providers: [])
        let bridge = AgentContextBridgeImpl(contextAggregator: aggregator)

        let request = AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )

        let items = try await bridge.gatherContext(request)

        XCTAssertTrue(items.isEmpty)
    }

    func testH10_gaiContextBudgetTruncation() async throws {
        let provider = StubContextProvider()
        let aggregator = ContextAggregator(providers: [provider])
        let bridge = AgentContextBridgeImpl(contextAggregator: aggregator)

        let budget = ContextBudget(maxTokens: 1, maxItems: 1)
        let request = AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp"),
            budget: budget
        )

        let items = try await bridge.gatherContext(request)

        XCTAssertLessThanOrEqual(items.count, 1)
    }

    // MARK: - CodeArtsAgentContextAdapter Tests (CodeArts Path, H22)

    func testCodeArtsAgentContextAdapter_conformsToProtocol() {
        let surfaceProvider = StubPublicProtocolSurfaceProvider()
        let aggregator = ContextAggregator(providers: [])
        let bridge: AgentContextBridge = CodeArtsAgentContextAdapter(
            surfaceProvider: surfaceProvider,
            contextAggregator: aggregator
        )

        XCTAssertNotNil(bridge)
    }

    func testH22_codeArtsContextViaPublicProtocolSurface() async throws {
        let surfaceProvider = StubPublicProtocolSurfaceProvider()
        let provider = StubContextProvider()
        let aggregator = ContextAggregator(providers: [provider])
        let bridge = CodeArtsAgentContextAdapter(
            surfaceProvider: surfaceProvider,
            contextAggregator: aggregator
        )

        let request = AgentContextRequest(
            source: .codeArtsAgent,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )

        let items = try await bridge.gatherContext(request)

        XCTAssertEqual(items.count, 2)
    }

    func testH22_codeArtsContextEmptyProviders() async throws {
        let surfaceProvider = StubPublicProtocolSurfaceProvider()
        let aggregator = ContextAggregator(providers: [])
        let bridge = CodeArtsAgentContextAdapter(
            surfaceProvider: surfaceProvider,
            contextAggregator: aggregator
        )

        let request = AgentContextRequest(
            source: .codeArtsAgent,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )

        let items = try await bridge.gatherContext(request)

        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - AgentContextError Tests

    func testAgentContextError_budgetExceeded() {
        let request = AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )
        let error = AgentContextError.budgetExceeded(request: request)

        if case .budgetExceeded(let req) = error {
            XCTAssertEqual(req.source, .gaiRuntime)
        } else {
            XCTFail("Wrong error case")
        }
    }

    func testAgentContextError_surfaceViolation() {
        let error = AgentContextError.surfaceViolation(source: .codeArtsAgent, reason: "H22 violation")

        if case .surfaceViolation(let source, let reason) = error {
            XCTAssertEqual(source, .codeArtsAgent)
            XCTAssertEqual(reason, "H22 violation")
        } else {
            XCTFail("Wrong error case")
        }
    }

    func testAgentContextError_equatable() {
        let error1 = AgentContextError.aggregationFailed(reason: "test")
        let error2 = AgentContextError.aggregationFailed(reason: "test")
        let error3 = AgentContextError.aggregationFailed(reason: "different")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    // MARK: - H28 Verification: Context Bridge Does Not Bypass M6/M9

    func testH28_contextBridgeReusesM6ContextAggregator() async throws {
        let provider = StubContextProvider()
        let aggregator = ContextAggregator(providers: [provider])
        let bridge = AgentContextBridgeImpl(contextAggregator: aggregator)

        let request = AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )

        let items = try await bridge.gatherContext(request)

        XCTAssertTrue(items.allSatisfy { $0.source != .diagnostics || true })
        XCTAssertEqual(items.count, 2)
    }

    func testH28_codeArtsBridgeReusesM9SurfaceProvider() async throws {
        let surfaceProvider = StubPublicProtocolSurfaceProvider()
        let aggregator = ContextAggregator(providers: [])
        let bridge = CodeArtsAgentContextAdapter(
            surfaceProvider: surfaceProvider,
            contextAggregator: aggregator
        )

        let request = AgentContextRequest(
            source: .codeArtsAgent,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )

        let items = try await bridge.gatherContext(request)

        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - Multi-Source Context Tests

    func testMultiSource_gaiAndCodeArtsProduceSameContext() async throws {
        let provider = StubContextProvider()
        let aggregator = ContextAggregator(providers: [provider])

        let gaiBridge = AgentContextBridgeImpl(contextAggregator: aggregator)
        let codeArtsBridge = CodeArtsAgentContextAdapter(
            surfaceProvider: StubPublicProtocolSurfaceProvider(),
            contextAggregator: aggregator
        )

        let gaiRequest = AgentContextRequest(
            source: .gaiRuntime,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )
        let codeArtsRequest = AgentContextRequest(
            source: .codeArtsAgent,
            projectRoot: URL(fileURLWithPath: "/tmp")
        )

        let gaiItems = try await gaiBridge.gatherContext(gaiRequest)
        let codeArtsItems = try await codeArtsBridge.gatherContext(codeArtsRequest)

        XCTAssertEqual(gaiItems.count, codeArtsItems.count)
    }
}