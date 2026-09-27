// TODO(M1): plugin host - three adapter surfaces (Native / VS Code / JetBrains)
import Foundation
import AppKCodeShared

public final class PluginHostService: @unchecked Sendable {
    public init() {}
    // TODO(M1): implement plugin host with ContractRegistry + three adapter surfaces
}

public final class ContractRegistry: DomainContractRegistry, @unchecked Sendable {
    private var contracts: [String: CompatibilityContract] = [:]
    private let lock = NSLock()

    public init() {}

    public func register(_ contract: CompatibilityContract) throws {
        lock.lock()
        defer { lock.unlock() }
        contracts[contract.contractID] = contract
    }

    public func lookup(_ contractID: String) -> CompatibilityContract? {
        lock.lock()
        defer { lock.unlock() }
        return contracts[contractID]
    }
}