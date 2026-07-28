import Foundation

public final class DSDDecoder: AudioDecoder {
    public let format: PCMFormat
    public let totalFrames: UInt64?

    private let fileHandle: FileHandle
    private let channelCount: Int
    private let blockSizePerChannel: Int
    private let dataOffset: UInt64
    private let dataSize: UInt64

    private var channelBuffers: [[UInt8]]
    private var blockReadOffset: Int = 0
    private var bytesConsumed: UInt64 = 0
    private var nextMarkerIsAlternate = false

    public init(url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)
        let container = try DSFContainer.parse(fileHandle: handle)

        self.fileHandle = handle
        self.channelCount = container.channelCount
        self.blockSizePerChannel = container.blockSizePerChannel
        self.dataOffset = container.dataOffset
        self.dataSize = container.dataSize
        self.format = PCMFormat(
            sampleRate: container.dsdBitRate / 16,
            bitDepth: 24,
            channelCount: container.channelCount
        )
        self.totalFrames = container.sampleCountPerChannel / 16
        self.channelBuffers = (0..<container.channelCount).map { _ in [] }

        try handle.seek(toOffset: container.dataOffset)
    }

    deinit {
        try? fileHandle.close()
    }

    public func readFrames(into destination: PCMBuffer) throws -> Int {
        var written = 0
        while written < destination.capacity {
            if blockReadOffset >= (channelBuffers.first?.count ?? 0) {
                guard try refillBlocks() else { break }
            }

            let availableBytes = (channelBuffers.first?.count ?? 0) - blockReadOffset
            let framesAvailable = availableBytes / 2
            guard framesAvailable > 0 else { break }
            let toWrite = min(framesAvailable, destination.capacity - written)

            for i in 0..<toWrite {
                let marker: UInt8 = nextMarkerIsAlternate ? 0xFA : 0x05
                nextMarkerIsAlternate.toggle()
                let byteIndex = blockReadOffset + i * 2
                for channel in 0..<channelCount {
                    let high = channelBuffers[channel][byteIndex]
                    let low = channelBuffers[channel][byteIndex + 1]
                    destination.channelData[channel][written + i] = Self.pack24(marker: marker, high: high, low: low)
                }
            }
            blockReadOffset += toWrite * 2
            written += toWrite
        }
        destination.setFrameCount(written)
        return written
    }

    public func seek(toFrame frame: UInt64) throws {
        let bitOffset = frame * 16
        let byteOffsetPerChannel = bitOffset / 8
        let blockIndex = byteOffsetPerChannel / UInt64(blockSizePerChannel)
        let blockBytes = UInt64(blockSizePerChannel) * UInt64(channelCount)
        let fileByteOffset = dataOffset + blockIndex * blockBytes

        try fileHandle.seek(toOffset: fileByteOffset)
        bytesConsumed = fileByteOffset - dataOffset
        blockReadOffset = 0
        for i in channelBuffers.indices { channelBuffers[i] = [] }
        nextMarkerIsAlternate = false
    }

    private func refillBlocks() throws -> Bool {
        guard bytesConsumed < dataSize else { return false }
        let remaining = dataSize - bytesConsumed
        let blockBytes = UInt64(blockSizePerChannel) * UInt64(channelCount)
        let toRead = Int(min(blockBytes, remaining))
        guard toRead > 0, let raw = try fileHandle.read(upToCount: toRead), !raw.isEmpty else { return false }
        bytesConsumed += UInt64(raw.count)

        let perChannel = raw.count / channelCount
        guard perChannel > 0 else { return false }
        let base = raw.startIndex
        for channel in 0..<channelCount {
            let start = base + channel * perChannel
            channelBuffers[channel] = Array(raw[start..<(start + perChannel)])
        }
        blockReadOffset = 0
        return true
    }

    static func pack24(marker: UInt8, high: UInt8, low: UInt8) -> Int32 {
        let unsigned24 = (UInt32(marker) << 16) | (UInt32(high) << 8) | UInt32(low)
        return Int32(bitPattern: unsigned24 << 8) >> 8
    }
}
