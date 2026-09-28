import XCTest
@testable import AppKCodeDomain
import AppKCodeShared
import AppKCodeInfrastructure

final class SkillRegistryTests: XCTestCase {
    func testRegisterAndResolve() throws {
        let registry = SkillRegistry()
        let manifest = SkillManifest(
            name: "test-skill",
            description: "Test skill",
            version: "1.0",
            inputSchema: JSONSchema(type: "object"),
            outputSchema: JSONSchema(type: "object"),
            executionPolicy: SkillExecutionPolicy()
        )

        try registry.register(manifest)
        let resolved = registry.resolve(manifest.id)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.name, "test-skill")
    }

    func testDuplicateRegistrationThrows() throws {
        let registry = SkillRegistry()
        let manifest = SkillManifest(
            name: "test-skill",
            description: "Test",
            version: "1.0",
            inputSchema: JSONSchema(type: "object"),
            outputSchema: JSONSchema(type: "object"),
            executionPolicy: SkillExecutionPolicy()
        )

        try registry.register(manifest)
        XCTAssertThrowsError(try registry.register(manifest)) { error in
            guard case SkillRegistryError.duplicateRegistration = error else {
                XCTFail("Expected duplicateRegistration error")
                return
            }
        }
    }

    func testUnregister() throws {
        let registry = SkillRegistry()
        let manifest = SkillManifest(
            name: "test-skill",
            description: "Test",
            version: "1.0",
            inputSchema: JSONSchema(type: "object"),
            outputSchema: JSONSchema(type: "object"),
            executionPolicy: SkillExecutionPolicy()
        )

        try registry.register(manifest)
        try registry.unregister(manifest.id)
        XCTAssertNil(registry.resolve(manifest.id))
    }

    func testListAll() throws {
        let registry = SkillRegistry()
        for i in 0..<3 {
            let manifest = SkillManifest(
                name: "skill-\(i)",
                description: "Skill \(i)",
                version: "1.0",
                inputSchema: JSONSchema(type: "object"),
                outputSchema: JSONSchema(type: "object"),
                executionPolicy: SkillExecutionPolicy()
            )
            try registry.register(manifest)
        }
        XCTAssertEqual(registry.listAll().count, 3)
    }

    func testListByCategory() throws {
        let registry = SkillRegistry()
        let manifest = SkillManifest(
            name: "categorized-skill",
            description: "Categorized",
            version: "1.0",
            inputSchema: JSONSchema(type: "object"),
            outputSchema: JSONSchema(type: "object"),
            executionPolicy: SkillExecutionPolicy(),
            metadata: ["category": "testing"]
        )
        try registry.register(manifest)
        XCTAssertEqual(registry.listByCategory("testing").count, 1)
        XCTAssertEqual(registry.listByCategory("coding").count, 0)
    }

    func testSkillExecutionPolicyDefaults() {
        let policy = SkillExecutionPolicy()
        XCTAssertTrue(policy.requireApproval, "H16: default requireApproval should be true")
        XCTAssertTrue(policy.sandboxed)
        XCTAssertGreaterThan(policy.maxSteps, 0)
        XCTAssertGreaterThan(policy.maxDurationSeconds, 0)
    }
}