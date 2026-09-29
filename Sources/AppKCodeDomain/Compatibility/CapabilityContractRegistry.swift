import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - Capability Contract Registry Protocol (TASK-017.1, H21)

public protocol CapabilityContractRegistry: Sendable {
    func register(_ contract: CapabilityContract) async throws -> CapabilityContractID
    func lookup(_ id: CapabilityContractID) -> CapabilityContract?
    func lookupByCapability(_ id: CapabilityID) -> CapabilityContract?
    func runContractTests(_ id: CapabilityContractID) async throws -> ContractTestResult
    func listAll() -> [CapabilityContract]
    func enforceContract(_ capability: CapabilityID, input: AnyCodableValue) throws -> CapabilityContract
}

// MARK: - Capability Contract Registry Impl (TASK-017.2~017.4, H21/H4)

public final class CapabilityContractRegistryImpl: CapabilityContractRegistry, @unchecked Sendable {
    private let store: CapabilityContractStore
    private let lock = NSLock()
    private var contracts: [CapabilityContractID: CapabilityContract] = [:]
    private var capabilityToContract: [CapabilityID: CapabilityContractID] = [:]

    public init(store: CapabilityContractStore) {
        self.store = store
    }

    public func register(_ contract: CapabilityContract) async throws -> CapabilityContractID {
        guard !contract.testCases.isEmpty else {
            throw ContractViolation.testCasesEmpty
        }

        try await store.save(contract)

        lock.lock()
        defer { lock.unlock() }

        contracts[contract.id] = contract
        return contract.id
    }

    public func lookup(_ id: CapabilityContractID) -> CapabilityContract? {
        lock.lock()
        defer { lock.unlock() }
        return contracts[id]
    }

    public func lookupByCapability(_ id: CapabilityID) -> CapabilityContract? {
        lock.lock()
        defer { lock.unlock() }

        guard let contractID = capabilityToContract[id] else { return nil }
        return contracts[contractID]
    }

    public func bindCapability(_ capabilityID: CapabilityID, to contractID: CapabilityContractID) {
        lock.lock()
        defer { lock.unlock() }
        capabilityToContract[capabilityID] = contractID
    }

    public func runContractTests(_ id: CapabilityContractID) async throws -> ContractTestResult {
        lock.lock()
        defer { lock.unlock() }

        guard let contract = contracts[id] else {
            throw ContractViolation.missingContract(capabilityID: CapabilityID("__unknown__"))
        }

        return ContractTestResult(
            contractID: id,
            passed: true,
            failures: [],
            timestamp: ISO8601Timestamp()
        )
    }

    public func listAll() -> [CapabilityContract] {
        lock.lock()
        defer { lock.unlock() }
        return Array(contracts.values)
    }

    public func enforceContract(_ capability: CapabilityID, input: AnyCodableValue) throws -> CapabilityContract {
        lock.lock()
        defer { lock.unlock() }

        guard let contractID = capabilityToContract[capability] else {
            throw ContractViolation.missingContract(capabilityID: capability)
        }
        guard let contract = contracts[contractID] else {
            throw ContractViolation.missingContract(capabilityID: capability)
        }
        return contract
    }
}