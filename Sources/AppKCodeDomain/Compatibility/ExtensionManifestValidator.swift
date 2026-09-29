import Foundation
import AppKCodeShared
import AppKCodeInfrastructure

// MARK: - Extension Validation Result (TASK-015.4)

public enum ExtensionValidationResult: Sendable, Equatable {
    case valid
    case invalid(reasons: [String])
}

// MARK: - Extension Manifest Validator (TASK-015)

public final class ExtensionManifestValidator: @unchecked Sendable {
    public init() {}

    public func validate(
        _ manifest: ExtensionManifest,
        availableContracts: [CapabilityContractID]
    ) -> ExtensionValidationResult {
        var reasons: [String] = []

        if manifest.name.isEmpty {
            reasons.append("name must not be empty")
        }

        if manifest.entryPoint.isEmpty {
            reasons.append("entryPoint must not be empty")
        }

        if manifest.architectures.isEmpty {
            reasons.append("architectures must not be empty")
        }

        if !availableContracts.contains(manifest.contractID) {
            reasons.append("contractID \(manifest.contractID.rawValue) not found in available contracts")
        }

        if !validateKindAPISurfaceConsistency(manifest.kind, manifest.apiSurface) {
            reasons.append("kind \(manifest.kind.rawValue) and apiSurface are inconsistent")
        }

        if reasons.isEmpty {
            return .valid
        }
        return .invalid(reasons: reasons)
    }

    public func checkArchitecture(_ manifest: ExtensionManifest) -> ArchitectureSupportResult {
        if manifest.architectures.contains(.x86_64) || manifest.architectures.contains(.universal) {
            return .nativelySupported
        }
        if manifest.architectures.contains(.arm64) {
            return .requiresDegradation
        }
        return .unsupported
    }

    private func validateKindAPISurfaceConsistency(_ kind: ExtensionKind, _ surface: APISurface) -> Bool {
        switch (kind, surface) {
        case (.codeartsAgent, .native), (.codeartsAgent, .mcp):
            return true
        case (.vscodeExtension, .vscode):
            return true
        case (.jetbrainsPlugin, .jetbrains):
            return true
        case (.lspServer, .lsp):
            return true
        case (.mcpServer, .mcp):
            return true
        case (.custom, _):
            return true
        default:
            return true
        }
    }
}