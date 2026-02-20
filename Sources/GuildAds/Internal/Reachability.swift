import Foundation
import Network

final class GuildAdsReachabilityMonitor: @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.guildads.reachability")
    private let lock = NSLock()
    private var _isReachable = true

    var onOnline: (@Sendable () -> Void)?

    init() {
        self.monitor = NWPathMonitor()
    }

    var isReachable: Bool {
        lock.withLock {
            _isReachable
        }
    }

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else {
                return
            }

            let reachable = path.status == .satisfied
            self.lock.withLock {
                self._isReachable = reachable
            }

            if reachable {
                self.onOnline?()
            }
        }

        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    deinit {
        stop()
    }
}

private extension NSLock {
    @discardableResult
    func withLock<T>(_ block: () -> T) -> T {
        lock()
        defer { unlock() }
        return block()
    }
}
