import Foundation
import AppKCodeShared

// MARK: - Capability Contract Store (TASK-011, H4/H21)

public final class CapabilityContractStore: @unchecked Sendable {
    private let contractsDir: URL
    private let lock = NSLock()

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.contractsDir = home
            .appendingPathComponent(".appkcode")
            .appendingPathComponent("contracts")
    }

    public init(customDir: URL) {
        self.contractsDir = customDir
    }

    public func save(_ contract: CapabilityContract) async throws {
        guard !contract.testCases.isEmpty else {
            throw ContractViolation.testCasesEmpty
        }

        let fm = FileManager.default
        try fm.createDirectory(at: contractsDir, withIntermediateDirectories: true)

        let fileURL = contractsDir.appendingPathComponent("\(contract.id.rawValue).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(contract)
        try data.write(to: fileURL)
    }

    public func load(_ id: CapabilityContractID) async throws -> CapabilityContract? {
        let fileURL = contractsDir.appendingPathComponent("\(id.rawValue).json")
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(CapabilityContract.self, from: data)
    }

    public func loadAll() async throws -> [CapabilityContract] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: contractsDir.path) else {
            return []
        }

        let entries = try fm.contentsOfDirectory(at: contractsDir, includingPropertiesForKeys: nil)
        let jsonFiles = entries.filter { $0.pathExtension == "json" }

        var contracts: [CapabilityContract] = []
        for file in jsonFiles {
            do {
                let data = try Data(contentsOf: file)
                let contract = try JSONDecoder().decode(CapabilityContract.self, from: data)
                contracts.append(contract)
            } catch {
                continue
            }
        }
        return contracts
    }

    public func remove(_ id: CapabilityContractID, referencedBy extensions: [ExtensionID] = []) async throws {
        if !extensions.isEmpty {
            throw CapabilityContractStoreError.contractInUse(id, extensions)
        }

        lock.lock()
        defer { lock.unlock() }

        let fileURL = contractsDir.appendingPathComponent("\(id.rawValue).json")
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            try fm.removeItem(at: fileURL)
        }
    }
}

public enum CapabilityContractStoreError: Error, Sendable {
    case contractInUse(CapabilityContractID, [ExtensionID])
}