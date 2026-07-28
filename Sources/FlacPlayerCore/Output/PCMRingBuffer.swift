import Darwin

final class PCMRingBuffer {
    let channelCount: Int
    private let capacity: Int
    private var storage: [UnsafeMutablePointer<Int32>]
    private var writeIndex = 0
    private var readIndex = 0
    private var count = 0
    private var lock = os_unfair_lock()

    init(channelCount: Int, capacity: Int) {
        self.channelCount = channelCount
        self.capacity = capacity
        self.storage = (0..<channelCount).map { _ in .allocate(capacity: capacity) }
    }

    deinit {
        for pointer in storage {
            pointer.deallocate()
        }
    }

    var availableToWrite: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return capacity - count
    }

    func reset() {
        os_unfair_lock_lock(&lock)
        writeIndex = 0
        readIndex = 0
        count = 0
        os_unfair_lock_unlock(&lock)
    }

    @discardableResult
    func write(from source: PCMBuffer) -> Int {
        os_unfair_lock_lock(&lock)
        let free = capacity - count
        let toWrite = min(free, source.frameCount)
        let startIndex = writeIndex
        os_unfair_lock_unlock(&lock)

        guard toWrite > 0 else { return 0 }
        let firstRun = min(toWrite, capacity - startIndex)
        let secondRun = toWrite - firstRun
        for channel in 0..<min(channelCount, source.channelCount) {
            storage[channel].advanced(by: startIndex).update(from: source.channelData[channel], count: firstRun)
            if secondRun > 0 {
                storage[channel].update(from: source.channelData[channel].advanced(by: firstRun), count: secondRun)
            }
        }

        os_unfair_lock_lock(&lock)
        writeIndex = (startIndex + toWrite) % capacity
        count += toWrite
        os_unfair_lock_unlock(&lock)
        return toWrite
    }

    @discardableResult
    func read(into destination: PCMBuffer, maxFrames: Int? = nil) -> Int {
        let limit = min(maxFrames ?? destination.capacity, destination.capacity)

        os_unfair_lock_lock(&lock)
        let available = count
        let startIndex = readIndex
        os_unfair_lock_unlock(&lock)

        let toRead = min(available, limit)
        guard toRead > 0 else {
            destination.setFrameCount(0)
            return 0
        }
        let firstRun = min(toRead, capacity - startIndex)
        let secondRun = toRead - firstRun
        for channel in 0..<min(channelCount, destination.channelCount) {
            destination.channelData[channel].update(from: storage[channel].advanced(by: startIndex), count: firstRun)
            if secondRun > 0 {
                destination.channelData[channel].advanced(by: firstRun).update(from: storage[channel], count: secondRun)
            }
        }

        os_unfair_lock_lock(&lock)
        readIndex = (startIndex + toRead) % capacity
        count -= toRead
        os_unfair_lock_unlock(&lock)

        destination.setFrameCount(toRead)
        return toRead
    }
}
