import XCTest
@testable import AppKCodeApplication
import AppKCodeDomain
import AppKCodeInfrastructure
import AppKCodeShared

final class ChatOrchestratorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AppKOrchTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func test_OrchestratorCreation() {
        let registry = ModelProviderRegistry()
        let resolver = LocalModeResolver()
        _ = resolver.resolveDefault(registry: registry)
        let store = ChatSessionStore()
        let chatService = ChatServiceImpl(registry: registry, store: store)
        let aggregator = ContextAggregator(providers: [])
        let orchestrator = ChatOrchestrator(
            chatService: chatService,
            contextAggregator: aggregator,
            registry: registry
        )
        XCTAssertNotNil(orchestrator)
    }

    func test_ContextAggregationServiceCreation() {
        let providers: [ContextProvider] = [
            CurrentFileContextProvider(),
            WorkspaceContextProvider()
        ]
        let service = ContextAggregationService(providers: providers)
        XCTAssertEqual(service.availableSources.count, 2)
        XCTAssertTrue(service.availableSources.contains(.currentFile))
        XCTAssertTrue(service.availableSources.contains(.workspace))
    }

    func test_ModelProviderApplicationServiceDefault() {
        let appService = ModelProviderApplicationService()
        let defaultProvider = appService.defaultProvider()
        XCTAssertEqual(defaultProvider.config.mode, .local)
        XCTAssertEqual(defaultProvider.config.endpoint, LocalModeDefaults.endpoint)
    }

    func test_ModelProviderApplicationServiceConfigureCloud() throws {
        let appService = ModelProviderApplicationService()
        let cloudConfig = ModelProviderConfig(
            kind: .cloudModel,
            mode: .cloud,
            endpoint: URL(string: "https://api.example.com")!,
            apiKey: "key",
            modelName: "cloud"
        )
        try appService.configureCloud(cloudConfig)
        XCTAssertEqual(appService.allProviders.count, 2)
    }

    func test_ModelProviderApplicationServiceSwitchProvider() throws {
        let appService = ModelProviderApplicationService()
        let cloudConfig = ModelProviderConfig(
            kind: .cloudModel,
            mode: .cloud,
            endpoint: URL(string: "https://api.example.com")!,
            apiKey: "key",
            modelName: "cloud"
        )
        try appService.configureCloud(cloudConfig)
        try appService.switchProvider(cloudConfig.id)
        XCTAssertEqual(appService.defaultProvider().id, cloudConfig.id)
    }

    func test_ContextAggregationServiceFilterBySource() async throws {
        let providers: [ContextProvider] = [
            CurrentFileContextProvider(),
            WorkspaceContextProvider()
        ]
        let service = ContextAggregationService(providers: providers)
        let request = ContextRequest(projectRoot: tempDir)
        let items = try await service.aggregate(request: request, sources: [.currentFile])
        for item in items {
            XCTAssertEqual(item.source, .currentFile)
        }
    }
}