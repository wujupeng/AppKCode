import Foundation
import AppKCodeShared

// MARK: - Protocol Boundary Service Protocol (TASK-028.1, H22)

public protocol ProtocolBoundaryService: Sendable {
    func getPublicSurface(for kind: AdapterKind) -> PublicProtocolSurface
    func interceptAccess(adapterID: AdapterID, api: APIName) throws -> PublicAPI
    func recordViolation(_ violation: ProtocolBoundaryViolation) async throws
    func listViolations(adapterID: AdapterID) -> [ProtocolBoundaryViolation]
}

// MARK: - Protocol Boundary Service Impl (TASK-028.2~028.4, H22)

public final class ProtocolBoundaryServiceImpl: ProtocolBoundaryService, @unchecked Sendable {
    private let surfaceProvider: PublicProtocolSurfaceProvider
    private let auditIntegration: ExtensionAuditIntegration
    private let lock = NSLock()
    private var violations: [AdapterID: [ProtocolBoundaryViolation]] = [:]

    public init(surfaceProvider: PublicProtocolSurfaceProvider, auditIntegration: ExtensionAuditIntegration) {
        self.surfaceProvider = surfaceProvider
        self.auditIntegration = auditIntegration
    }

    public func getPublicSurface(for kind: AdapterKind) -> PublicProtocolSurface {
        surfaceProvider.surface(for: kind)
    }

    public func interceptAccess(adapterID: AdapterID, api: APIName) throws -> PublicAPI {
        let kind = inferAdapterKind(from: adapterID)
        let surface = surfaceProvider.surface(for: kind)

        for publicAPI in surface.apis {
            if publicAPI.name == api {
                return publicAPI
            }
        }

        if surface.deprecated.contains(api) {
            let violation = ProtocolBoundaryViolation(
                adapterID: adapterID,
                attemptedAPI: api,
                accessKind: .privateInternal,
                reason: "API \(api.namespace).\(api.method) is deprecated"
            )
            Task { try? await recordViolation(violation) }
            throw AdapterError.apiNotSupported(api)
        }

        let violation = ProtocolBoundaryViolation(
            adapterID: adapterID,
            attemptedAPI: api,
            accessKind: .forbidden,
            reason: "API \(api.namespace).\(api.method) is not in public protocol surface (H22)"
        )
        Task { try? await recordViolation(violation) }
        throw AdapterError.hostInternalAccess
    }

    public func recordViolation(_ violation: ProtocolBoundaryViolation) async throws {
        lock.lock()
        if violations[violation.adapterID] == nil {
            violations[violation.adapterID] = []
        }
        violations[violation.adapterID]?.append(violation)
        lock.unlock()

        let event = M9AuditEvent(
            kind: .adapterBoundaryViolation,
            extensionID: nil,
            detail: .string("Boundary violation: \(violation.reason)")
        )
        try await auditIntegration.recordExtensionEvent(event)
    }

    public func listViolations(adapterID: AdapterID) -> [ProtocolBoundaryViolation] {
        lock.lock()
        defer { lock.unlock() }
        return violations[adapterID] ?? []
    }

    public func buildPublicSurface(apis: [PublicAPI], version: SemVer) -> PublicProtocolSurface {
        PublicProtocolSurface(apis: apis, version: version, deprecated: [])
    }

    private func inferAdapterKind(from id: AdapterID) -> AdapterKind {
        return .codearts
    }
}