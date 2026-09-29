import Foundation
import AppKCodeShared
import AppKCodeDomain

// MARK: - Capability App Service Protocol (TASK-032.1)

public protocol CapabilityAppService: Sendable {
    func listCapabilities() async -> [CapabilityDescriptor]
    func listCapabilities(byCategory: CapabilityCategory) async -> [CapabilityDescriptor]
    func listCapabilities(forExtension: ExtensionID) async -> [CapabilityDescriptor]
    func invokeCapability(_ id: CapabilityID, extensionID: ExtensionID, input: AnyCodableValue, sessionID: AgentSessionID) async throws -> CapabilityInvocationResult
    func runContractTests(_ contractID: CapabilityContractID) async throws -> ContractTestResult
}

// MARK: - Capability App Service Impl (TASK-032.2, H20/H21/H22/H23)

public final class CapabilityAppServiceImpl: CapabilityAppService, @unchecked Sendable {
    private let capabilityRegistry: CapabilityRegistry
    private let contractRegistry: CapabilityContractRegistry
    private let authIntegration: ExtensionAuthorizationIntegration
    private let auditIntegration: ExtensionAuditIntegration
    private let adapter: RuntimeAdapter?

    public init(
        capabilityRegistry: CapabilityRegistry,
        contractRegistry: CapabilityContractRegistry,
        authIntegration: ExtensionAuthorizationIntegration,
        auditIntegration: ExtensionAuditIntegration,
        adapter: RuntimeAdapter? = nil
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.contractRegistry = contractRegistry
        self.authIntegration = authIntegration
        self.auditIntegration = auditIntegration
        self.adapter = adapter
    }

    public func listCapabilities() async -> [CapabilityDescriptor] {
        capabilityRegistry.listAll()
    }

    public func listCapabilities(byCategory: CapabilityCategory) async -> [CapabilityDescriptor] {
        capabilityRegistry.listByCategory(byCategory)
    }

    public func listCapabilities(forExtension id: ExtensionID) async -> [CapabilityDescriptor] {
        capabilityRegistry.listByExtension(id)
    }

    public func invokeCapability(
        _ id: CapabilityID,
        extensionID: ExtensionID,
        input: AnyCodableValue,
        sessionID: AgentSessionID
    ) async throws -> CapabilityInvocationResult {
        // H21: Contract enforcement — no contract, no execution
        let contract = try contractRegistry.enforceContract(id, input: input)

        // H20: Authorization — Extension must have permission
        let authResult = try await authIntegration.authorize(
            extensionID: extensionID,
            capability: id,
            permission: contract.requiredPermission,
            sessionID: sessionID
        )

        switch authResult {
        case .denied(let reason):
            // H23: Audit denial
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .capabilityDenied,
                sessionID: sessionID,
                extensionID: extensionID,
                detail: .string("Denied: \(reason)")
            ))
            return .denied(reason: reason)

        case .requiresUserApproval(let request):
            // H20: High-risk requires user approval — return pending
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .permissionRequested,
                sessionID: sessionID,
                extensionID: extensionID,
                detail: .string("Requires approval: \(request.justification)")
            ))
            return .denied(reason: "Requires user approval: \(request.justification)")

        case .allowed:
            // H23: Audit invocation
            try await auditIntegration.recordExtensionEvent(M9AuditEvent(
                kind: .capabilityInvoked,
                sessionID: sessionID,
                extensionID: extensionID,
                detail: .string("Invoking capability: \(id.rawValue)")
            ))

            // H22: Execute via Adapter (not direct execution)
            if let adapter = adapter {
                return try await adapter.invokeCapability(id, input: input, sessionID: sessionID)
            }

            // No adapter — return degraded
            return .degraded(reason: "No adapter available for capability \(id.rawValue)", partialOutput: nil)
        }
    }

    public func runContractTests(_ contractID: CapabilityContractID) async throws -> ContractTestResult {
        try await contractRegistry.runContractTests(contractID)
    }
}