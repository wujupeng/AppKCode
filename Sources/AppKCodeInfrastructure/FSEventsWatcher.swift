import Foundation
import AppKCodeShared

public final class FSEventsWatcher: @unchecked Sendable {
    private var stream: FSEventStream?
    private let callback: @Sendable (Set<URL>) -> Void
    private let queue = DispatchQueue(label: "appk.fsevents", qos: .utility)

    public init(callback: @escaping @Sendable (Set<URL>) -> Void) {
        self.callback = callback
    }

    public func startWatching(directory: URL) {
        stopWatching()
        let flags: FSEventStreamEventFlags = [.fileEvents, .watchRoot]
        let stream = FSEventStream.create(
            queue: queue,
            handler: { [weak self] _ in
                guard let self = self else { return }
                self.callback([directory])
            },
            paths: [directory],
            sinceEventId: .now,
            latency: 0.3,
            flags: flags
        )
        stream.start()
        self.stream = stream
    }

    public func stopWatching() {
        stream?.stop()
        stream = nil
    }

    deinit {
        stopWatching()
    }
}