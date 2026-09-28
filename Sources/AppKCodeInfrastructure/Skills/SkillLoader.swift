import Foundation
import AppKCodeShared

// MARK: - Skill Loader (TASK-010)

public final class SkillLoader: @unchecked Sendable {
    public init() {}

    public func loadFromDirectory(_ dir: URL) async throws -> [SkillManifest] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else {
            return []
        }

        let entries = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let skillFiles = entries.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasSuffix(".skill.json") }

        var manifests: [SkillManifest] = []
        for file in skillFiles {
            do {
                let data = try Data(contentsOf: file)
                let manifest = try JSONDecoder().decode(SkillManifest.self, from: data)
                manifests.append(manifest)
            } catch {
                continue
            }
        }
        return manifests
    }

    public func loadBuiltinSkills() async throws -> [SkillManifest] {
        let builtinPath = URL(fileURLWithPath: "Resources/Skills")
        return try await loadFromDirectory(builtinPath)
    }
}

// MARK: - Skill Store (TASK-010.3)

public final class SkillStore: @unchecked Sendable {
    private let registryURL: URL

    public init(workspaceRoot: URL) {
        self.registryURL = workspaceRoot
            .appendingPathComponent(".appkcode")
            .appendingPathComponent("skills")
            .appendingPathComponent("registry.json")
    }

    public func save(_ manifests: [SkillManifest]) async throws {
        let fm = FileManager.default
        let dir = registryURL.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(manifests)
        try data.write(to: registryURL)
    }

    public func load() async throws -> [SkillManifest] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: registryURL.path) else {
            return []
        }

        let data = try Data(contentsOf: registryURL)
        return try JSONDecoder().decode([SkillManifest].self, from: data)
    }
}