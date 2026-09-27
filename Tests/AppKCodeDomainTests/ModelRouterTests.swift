import XCTest
@testable import AppKCodeDomain
@testable import AppKCodeShared

final class ModelRouterTests: XCTestCase {
    func testDefaultRouteIsLocal() {
        let router = ModelRouter()
        for taskType in [TaskType.codeCompletion, .codeReview, .intentRecognition, .reportGeneration, .embedding] {
            let endpoint = router.route(taskType: taskType)
            XCTAssertEqual(endpoint.mode, .local, "Task \(taskType) should default to local mode")
            XCTAssertEqual(endpoint.url.host, "127.0.0.1", "Task \(taskType) should default to 127.0.0.1")
        }
    }

    func testLocalModeEndpointValidation() {
        let router = ModelRouter()
        let endpoint = router.route(taskType: .codeCompletion)
        XCTAssertEqual(endpoint.url.absoluteString, "http://127.0.0.1:8080")
    }

    func testRouteUpdate() {
        let router = ModelRouter()
        let cloudEndpoint = ModelEndpoint(url: URL(string: "https://api.example.com")!, mode: .cloud)
        router.updateRoute(taskType: .codeCompletion, endpoint: cloudEndpoint)
        let routed = router.route(taskType: .codeCompletion)
        XCTAssertEqual(routed.mode, .cloud)
    }
}