import CoreServices
import Foundation

public final class FolderWatcher {
    private var streamRef: FSEventStreamRef?
    private let paths: [String]
    private let handler: () -> Void
    private let queue = DispatchQueue(label: "FlacPlayer.FolderWatcher")

    public init(paths: [String], handler: @escaping () -> Void) {
        self.paths = paths
        self.handler = handler
    }

    public func start() {
        guard streamRef == nil, !paths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            fsEventsCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        streamRef = stream
    }

    public func stop() {
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil
    }

    fileprivate func notifyChange() {
        handler()
    }

    deinit {
        stop()
    }
}

private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let clientCallBackInfo else { return }
    Unmanaged<FolderWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue().notifyChange()
}
