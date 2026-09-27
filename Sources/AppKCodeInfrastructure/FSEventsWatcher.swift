import Foundation
import AppKCodeShared

public final class FSEventsWatcher: @unchecked Sendable {
    private var timer: DispatchSourceTimer?
    private let callback: @Sendable (Set<URL>) -> Void
    private let queue = DispatchQueue(label: "appk.fsevents", qos: .utility)
    private var watchedDirectory: URL?

    public init(callback: @escaping @Sendable (Set<URL>) -> Void) {
        self.callback = callback
    }

    public func startWatching(directory: URL) {
        stopWatching()
        watchedDirectory = directory
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
        timer.setEventHandler { [weak self] in
            guard let self = self, let dir = self.watchedDirectory else { return }
            self.callback([dir])
        }
        timer.resume()
        self.timer = timer
    }

    public func stopWatching() {
        timer?.cancel()
        timer = nil
        watchedDirectory = nil
    }

    deinit {
        stopWatching()
    }
}
