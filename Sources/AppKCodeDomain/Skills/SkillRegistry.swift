import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - Skill Registry (TASK-017)

public final class SkillRegistry: @unchecked Sendable {
    private var skills: [SkillID: SkillManifest] = [:]
    private let lock = NSLock()

    public init() {}

    public func register(_ manifest: SkillManifest) throws {
        lock.lock()
        defer { lock.unlock() }
        if skills[manifest.id] != nil {
            throw SkillRegistryError.duplicateRegistration(manifest.id)
        }
        skills[manifest.id] = manifest
    }

    public func unregister(_ id: SkillID) throws {
        lock.lock()
        defer { lock.unlock() }
        guard skills.removeValue(forKey: id) != nil else {
            throw SkillRegistryError.skillNotFound(id)
        }
    }

    public func resolve(_ id: SkillID) -> SkillManifest? {
        lock.lock()
        defer { lock.unlock() }
        return skills[id]
    }

    public func listAll() -> [SkillManifest] {
        lock.lock()
        defer { lock.unlock() }
        return Array(skills.values).sorted { $0.name < $1.name }
    }

    public func listByCategory(_ category: String) -> [SkillManifest] {
        lock.lock()
        defer { lock.unlock() }
        return skills.values
            .filter { $0.metadata["category"] == category }
            .sorted { $0.name < $1.name }
    }

    public func loadFromDirectory(_ dir: URL) async throws -> [SkillID] {
        let loader = SkillLoader()
        let manifests = try await loader.loadFromDirectory(dir)
        var registeredIDs: [SkillID] = []
        for manifest in manifests {
            do {
                try register(manifest)
                registeredIDs.append(manifest.id)
            } catch {
                continue
            }
        }
        return registeredIDs
    }

    public func reload(_ dir: URL) async throws -> ReloadResult {
        let loader = SkillLoader()
        let newManifests = try await loader.loadFromDirectory(dir)
        let newIDs = Set(newManifests.map { $0.id })

        lock.lock()
        let oldIDs = Set(skills.keys)
        let toRemove = oldIDs.subtracting(newIDs)
        let toAdd = newIDs.subtracting(oldIDs)
        let common = oldIDs.intersection(newIDs)

        var updated = 0
        for id in common {
            if let newManifest = newManifests.first(where: { $0.id == id }),
               let oldManifest = skills[id],
               newManifest.version != oldManifest.version {
                skills[id] = newManifest
                updated += 1
            }
        }

        for id in toRemove {
            skills.removeValue(forKey: id)
        }

        for manifest in newManifests where toAdd.contains(manifest.id) {
            skills[manifest.id] = manifest
        }
        lock.unlock()

        return ReloadResult(added: toAdd.count, removed: toRemove.count, updated: updated)
    }
}

// MARK: - Skill Registry Error

public enum SkillRegistryError: Error, Sendable {
    case duplicateRegistration(SkillID)
    case skillNotFound(SkillID)
}