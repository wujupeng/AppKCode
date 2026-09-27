import XCTest
@testable import AppKCodeApplication
@testable import AppKCodeShared

final class WorkspacePersistenceTests: XCTestCase {
    private var tempConfigDir: URL!

    override func setUpWithError() throws {
        tempConfigDir = FileManager.default.temporaryDirectory.appendingPathComponent("appk-ws-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempConfigDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempConfigDir)
    }

    private func makeService() -> WorkspaceService {
        WorkspaceService()
    }

    func testSaveAndLoadWorkspace() throws {
        let service = makeService()
        let tempProject = tempConfigDir.appendingPathComponent("MyProject")
        try FileManager.default.createDirectory(at: tempProject, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempProject) }

        _ = try service.openFolder(url: tempProject)
        try service.saveWorkspace()

        let loaded = service.loadPersistedWorkspace()
        XCTAssertNotNil(loaded, "loadPersistedWorkspace should return the saved URL")
        XCTAssertEqual(loaded?.path, tempProject.path)
    }

    func testLoadPersistedWorkspaceReturnsNilWhenNoFile() {
        let service = makeService()
        try? service.clearPersistedWorkspace()
        let loaded = service.loadPersistedWorkspace()
        XCTAssertNil(loaded, "Should return nil when no workspace.json exists")
    }

    func testClearPersistedWorkspace() throws {
        let service = makeService()
        let tempProject = tempConfigDir.appendingPathComponent("ClearTest")
        try FileManager.default.createDirectory(at: tempProject, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempProject) }

        _ = try service.openFolder(url: tempProject)
        try service.saveWorkspace()
        try service.clearPersistedWorkspace()

        let loaded = service.loadPersistedWorkspace()
        XCTAssertNil(loaded, "After clear, load should return nil")
    }

    func testCorruptedJSONReturnsNil() throws {
        let service = makeService()
        let tempProject = tempConfigDir.appendingPathComponent("CorruptTest")
        try FileManager.default.createDirectory(at: tempProject, withIntermediateDirectories: true)
        _ = try service.openFolder(url: tempProject)
        try service.saveWorkspace()

        let configURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".appk/workspace.json")
        try "not valid json".write(to: configURL, atomically: true, encoding: .utf8)

        let loaded = service.loadPersistedWorkspace()
        XCTAssertNil(loaded, "Corrupted JSON should return nil, not crash")

        try? service.clearPersistedWorkspace()
        try? FileManager.default.removeItem(at: tempProject)
    }

    func testNonExistentPathReturnsNil() throws {
        let service = makeService()
        let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".appk")
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let configURL = configDir.appendingPathComponent("workspace.json")
        let json = ["rootPath": "/nonexistent/path/that/does/not/exist"]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: configURL)

        let loaded = service.loadPersistedWorkspace()
        XCTAssertNil(loaded, "Non-existent path should return nil")

        try? service.clearPersistedWorkspace()
    }
}