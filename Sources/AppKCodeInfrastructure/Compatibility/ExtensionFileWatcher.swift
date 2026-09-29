import Foundation
import AppKCodeShared

// MARK: - Extension Reload Event (TASK-013.2)

public enum ExtensionReloadEvent: Sendable, Equatable {
    case added(ExtensionID)
    case modified(ExtensionID)
    case removed(ExtensionID)
    case parseError(file: URL, error: String)
}

// MARK: - Extension File Watcher (TASK-013)

public final class ExtensionFileWatcher: @unchecked Sendable {
    private let watchPath: URL
    private var source: DispatchSourceFileSystemObject?
    private var eventContinuation: AsyncStream<ExtensionReloadEvent>.Continuation?
    private let loader: ExtensionManifestLoader
    private var lastValidManifests: [ExtensionManifest] = []

    public init(watchPath: URL) {
        self.watchPath = watchPath
        self.loader = ExtensionManifestLoader()
    }

    public var events: AsyncStream<ExtensionReloadEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    public func startWatching() {
        let fd = open(watchPath.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .global()
        )

        source.setEventHandler { [weak self] in
            self?.handleDirectoryChange()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.source = source
    }

    public func stopWatching() {
        source?.cancel()
        source = nil
    }

    private func handleDirectoryChange() {
        Task { [weak self] in
            guard let self = self else { return }

            let previousIDs = Set(self.lastValidManifests.map { $0.id })

            do {
                let newManifests = try await self.loader.loadFromDirectory(self.watchPath)
                let newIDs = Set(newManifests.map { $0.id })

                for manifest in newManifests {
                    if !previousIDs.contains(manifest.id) {
                        self.eventContinuation?.yield(.added(manifest.id))
                    } else {
                        self.eventContinuation?.yield(.modified(manifest.id))
                    }
                }

                for oldID in previousIDs where !newIDs.contains(oldID) {
                    self.eventContinuation?.yield(.removed(oldID))
                }

                self.lastValidManifests = newManifests
            } catch {
                self.eventContinuation?.yield(.parseError(file: self.watchPath, error: String(describing: error)))
            }
        }
    }

    public func currentManifests() -> [ExtensionManifest] {
        lastValidManifests
    }
}