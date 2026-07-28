import Foundation

struct DSFContainer {
    let dsdBitRate: Double
    let channelCount: Int
    let blockSizePerChannel: Int
    let sampleCountPerChannel: UInt64
    let dataOffset: UInt64
    let dataSize: UInt64

    static func parse(fileHandle: FileHandle) throws -> DSFContainer {
        try fileHandle.seek(toOffset: 0)

        guard let dsdChunk = try fileHandle.read(upToCount: 28), dsdChunk.count == 28,
              Array(dsdChunk.prefix(4)) == Array("DSD ".utf8)
        else {
            throw AudioDecoderError.failedToOpenFile("not a DSF file")
        }

        guard let fmtChunk = try fileHandle.read(upToCount: 52), fmtChunk.count == 52,
              Array(fmtChunk.prefix(4)) == Array("fmt ".utf8)
        else {
            throw AudioDecoderError.decodeError("missing fmt chunk")
        }

        let channelCount = Int(readUInt32(fmtChunk, at: 24))
        let dsdBitRate = Double(readUInt32(fmtChunk, at: 28))
        let sampleCountPerChannel = readUInt64(fmtChunk, at: 36)
        let blockSizePerChannel = Int(readUInt32(fmtChunk, at: 44))

        guard let dataHeader = try fileHandle.read(upToCount: 12), dataHeader.count == 12,
              Array(dataHeader.prefix(4)) == Array("data".utf8)
        else {
            throw AudioDecoderError.decodeError("missing data chunk")
        }
        let dataChunkSize = readUInt64(dataHeader, at: 4)

        guard channelCount > 0, blockSizePerChannel > 0, dsdBitRate > 0, dataChunkSize >= 12 else {
            throw AudioDecoderError.decodeError("invalid DSF format chunk")
        }

        return DSFContainer(
            dsdBitRate: dsdBitRate,
            channelCount: channelCount,
            blockSizePerChannel: blockSizePerChannel,
            sampleCountPerChannel: sampleCountPerChannel,
            dataOffset: 28 + 52 + 12,
            dataSize: dataChunkSize - 12
        )
    }
}

private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
    data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }.littleEndian
}

private func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
    data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self) }.littleEndian
}
