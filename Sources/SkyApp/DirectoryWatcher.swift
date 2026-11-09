import CoreServices
import Foundation
import SkyCore

/// Reports paths of files created, renamed, modified or removed directly inside
/// one directory, using FSEvents. Changes in subdirectories are ignored.
final class DirectoryWatcher {
    let directory: URL
    private let onChange: ([String]) -> Void
    private var stream: FSEventStreamRef?

    init(directory: URL, onChange: @escaping ([String]) -> Void) {
        self.directory = directory
        self.onChange = onChange
    }

    deinit { stop() }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            let changed = (unsafeBitCast(paths, to: NSArray.self) as? [String]) ?? []
            watcher.deliver(changed)
        }
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            nil, callback, &context,
            [directory.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.05, flags
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func deliver(_ paths: [String]) {
        let parent = ScreenshotFiles.canonical(directory).path
        let direct = Set(paths.filter {
            ScreenshotFiles.canonical(URL(fileURLWithPath: $0).deletingLastPathComponent()).path == parent
        })
        if !direct.isEmpty { onChange(Array(direct)) }
    }
}
