import Foundation
import Testing
@testable import FlacPlayerCore

private func fixture(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
}

@Test func decodeWorkerChainsIntoNextDecoderSeamlessly() async throws {
    let firstDecoder = try FLACDecoder(url: fixture("tone_44k16.flac"))
    let secondDecoder = try FLACDecoder(url: fixture("tone_96k24.flac"))
    let expectedTotalFrames = Int(firstDecoder.totalFrames!) + Int(secondDecoder.totalFrames!)

    let ringBuffer = PCMRingBuffer(channelCount: 2, capacity: 8192)
    let providedNext = Locked(false)
    let finished = Locked(false)

    let worker = DecodeWorker(
        decoder: firstDecoder,
        ringBuffer: ringBuffer,
        nextDecoderProvider: {
            guard providedNext.exchange(true) == false else { return nil }
            return secondDecoder
        },
        onFinished: { finished.set(true) }
    )
    worker.start()

    var totalDrained = 0
    let drain = PCMBuffer(channelCount: 2, capacity: 4096)
    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline {
        let read = ringBuffer.read(into: drain, maxFrames: drain.capacity)
        totalDrained += read
        if read == 0 {
            if finished.isSet && ringBuffer.availableToWrite == 8192 {
                break
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    #expect(finished.isSet)
    #expect(totalDrained == expectedTotalFrames)
}

private final class Locked {
    private var value: Bool
    private let lock = NSLock()

    init(_ value: Bool) {
        self.value = value
    }

    func set(_ newValue: Bool) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
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
