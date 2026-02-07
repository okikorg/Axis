import Foundation

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
        guard descriptor >= 0 else { return }

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
        if descriptor >= 0 {
            close(descriptor)
            descriptor = -1
        }
    }

    deinit {
        stop()
    }
}
