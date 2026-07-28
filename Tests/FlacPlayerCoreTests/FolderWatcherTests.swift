import Foundation
import Testing
@testable import FlacPlayerCore

@Test func firesHandlerWhenFileAppearsInWatchedFolder() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    await confirmation("watcher fires on new file") { fired in
        let box = Locked(false)
        let watcher = FolderWatcher(paths: [root.path]) {
            if box.exchange(true) == false {
                fired()
            }
        }
        watcher.start()
        try? await Task.sleep(for: .milliseconds(500))

        try? "hello".write(to: root.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)

        try? await Task.sleep(for: .seconds(3))
        watcher.stop()
    }
}

private final class Locked {
    private var value: Bool
    private let lock = NSLock()

    init(_ value: Bool) {
        self.value = value
    }

    @discardableResult
    func exchange(_ newValue: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let old = value
        value = newValue
        return old
    }
}
