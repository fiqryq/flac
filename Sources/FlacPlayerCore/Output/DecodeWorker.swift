import Darwin
import Foundation

final class DecodeWorker: @unchecked Sendable {
    private var decoder: AudioDecoder
    private let ringBuffer: PCMRingBuffer
    private let nextDecoderProvider: (() -> AudioDecoder?)?
    private let onFinished: (() -> Void)?
    private let onSeeked: ((UInt64) -> Void)?
    private let stopFlag = AtomicFlag()
    private var thread: Thread?

    private var pendingSeekFrame: UInt64?
    private var seekLock = os_unfair_lock()

    init(
        decoder: AudioDecoder,
        ringBuffer: PCMRingBuffer,
        nextDecoderProvider: (() -> AudioDecoder?)? = nil,
        onFinished: (() -> Void)? = nil,
        onSeeked: ((UInt64) -> Void)? = nil
    ) {
        self.decoder = decoder
        self.ringBuffer = ringBuffer
        self.nextDecoderProvider = nextDecoderProvider
        self.onFinished = onFinished
        self.onSeeked = onSeeked
    }

    func start() {
        let thread = Thread { [weak self] in
            self?.runLoop()
        }
        thread.name = "FlacPlayer.DecodeWorker"
        thread.qualityOfService = .userInitiated
        thread.start()
        self.thread = thread
    }

    func stop() {
        stopFlag.set()
    }

    func requestSeek(toFrame frame: UInt64) {
        os_unfair_lock_lock(&seekLock)
        pendingSeekFrame = frame
        os_unfair_lock_unlock(&seekLock)
    }

    private func consumePendingSeek() -> UInt64? {
        os_unfair_lock_lock(&seekLock)
        let frame = pendingSeekFrame
        pendingSeekFrame = nil
        os_unfair_lock_unlock(&seekLock)
        return frame
    }

    private func runLoop() {
        let scratch = PCMBuffer(channelCount: ringBuffer.channelCount, capacity: 4096)
        while !stopFlag.isSet {
            if let seekFrame = consumePendingSeek() {
                ringBuffer.reset()
                try? decoder.seek(toFrame: seekFrame)
                onSeeked?(seekFrame)
            }
            guard ringBuffer.availableToWrite >= scratch.capacity else {
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }
            guard let framesRead = try? decoder.readFrames(into: scratch), framesRead > 0 else {
                guard let next = nextDecoderProvider?() else {
                    onFinished?()
                    return
                }
                decoder = next
                continue
            }
            ringBuffer.write(from: scratch)
        }
    }
}
