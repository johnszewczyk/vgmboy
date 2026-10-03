import CoreServices
import Foundation

final class MarkdownDirectoryWatcher: @unchecked Sendable {
    private let root: URL
    private let onChange: @Sendable () -> Void
    private var stream: FSEventStreamRef?

    init(root: URL, onChange: @escaping @Sendable () -> Void) {
        self.root = root
        self.onChange = onChange
    }

    func start() {
        guard stream == nil else { return }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, eventCount, _, _, _ in
            guard eventCount > 0, let info else { return }
            let watcher = Unmanaged<MarkdownDirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.onChange()
        }
        let paths = [root.path] as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            flags
        ) else { return }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}
