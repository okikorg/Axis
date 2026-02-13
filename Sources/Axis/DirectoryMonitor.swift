import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.okik.axis", category: "DirectoryMonitor")

final class DirectoryMonitor {
    private let url: URL
    private let handler: () -> Void
    private var descriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?

    init(url: URL, handler: @escaping () -> Void) {
        self.url = url
        self.handler = handler
    }

    func start() {
        stop()
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            logger.warning("Failed to open \(self.url.path, privacy: .public) for monitoring (errno \(errno)). Directory changes won't be detected — check sandbox / security-scoped bookmark.")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .attrib, .extend],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler(handler: handler)
        source.setCancelHandler { [descriptor] in
            close(descriptor)
        }
        self.source = source
        source.resume()
    }

    func stop() {
        if let source {
            source.cancel()
            self.source = nil
        }
        // The cancel handler owns closing the descriptor.
        // Just mark it invalid to prevent deinit from re-entering.
        descriptor = -1
    }

    deinit {
        stop()
    }
}
