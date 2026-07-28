public final class PCMBuffer {
    public let channelCount: Int
    public let capacity: Int
    public private(set) var frameCount: Int = 0
    public let channelData: [UnsafeMutablePointer<Int32>]

    public init(channelCount: Int, capacity: Int) {
        self.channelCount = channelCount
        self.capacity = capacity
        self.channelData = (0..<channelCount).map { _ in
            UnsafeMutablePointer<Int32>.allocate(capacity: capacity)
        }
    }

    deinit {
        for pointer in channelData {
            pointer.deallocate()
        }
    }

    public func setFrameCount(_ count: Int) {
        precondition(count <= capacity, "frame count \(count) exceeds buffer capacity \(capacity)")
        frameCount = count
    }
}
