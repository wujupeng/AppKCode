import Foundation
import AppKCodeShared

// MARK: - Extension Manifest Loader (TASK-009)

public final class ExtensionManifestLoader: @unchecked Sendable {
    public init() {}

    public func loadFromDirectory(_ dir: URL) async throws -> [ExtensionManifest] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else {
            return []
        }

        let entries = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let extensionFiles = entries.filter {
            $0.pathExtension == "json" && $0.lastPathComponent.hasSuffix(".extension.json")
        }

        var manifests: [ExtensionManifest] = []
        for file in extensionFiles {
            do {
                let manifest = try await loadSingle(file)
                manifests.append(manifest)
            } catch {
                continue
            }
        }
        return manifests
    }

    public func loadSingle(_ file: URL) async throws -> ExtensionManifest {
        let data = try Data(contentsOf: file)
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(ExtensionManifest.self, from: data)

        guard !manifest.name.isEmpty else {
            throw ExtensionManifestLoadError.missingRequiredField("name")
        }
        guard !manifest.entryPoint.isEmpty else {
            throw ExtensionManifestLoadError.missingRequiredField("entryPoint")
        }

        return manifest
    }

    public func loadBuiltinExtensions() async throws -> [ExtensionManifest] {
        let builtinPath = URL(fileURLWithPath: "Resources/Compatibility")
        return try await loadFromDirectory(builtinPath)
    }

    public func checkArchitectureSupport(_ manifest: ExtensionManifest) -> ArchitectureSupportResult {
        if manifest.architectures.contains(.x86_64) || manifest.architectures.contains(.universal) {
            return .nativelySupported
        }
        if manifest.architectures.contains(.arm64) {
            return .requiresDegradation
        }
        return .unsupported
    }
}

public enum ArchitectureSupportResult: Sendable, Equatable {
    case nativelySupported
    case requiresDegradation
    case unsupported
}

public enum ExtensionManifestLoadError: Error, Sendable {
    case missingRequiredField(String)
    case invalidJSON(String)
}