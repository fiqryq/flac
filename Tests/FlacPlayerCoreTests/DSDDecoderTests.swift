import Foundation
import Testing
@testable import FlacPlayerCore

@Test func pack24ProducesCorrectSignedValues() {
    #expect(DSDDecoder.pack24(marker: 0x05, high: 0x00, low: 0x00) == 327_680)
    #expect(DSDDecoder.pack24(marker: 0xFA, high: 0x00, low: 0x00) == -393_216)
    #expect(DSDDecoder.pack24(marker: 0x05, high: 0xFF, low: 0xFF) == 0x05FFFF)
}

@Test func parsesMinimalDSFAndPacksDoPFrames() throws {
    let payload: [UInt8] = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]
    let url = try makeDSFFile(channelCount: 1, blockSizePerChannel: 4, dsdBitRate: 2_822_400, payload: payload)
    defer { try? FileManager.default.removeItem(at: url) }

    let decoder = try DSDDecoder(url: url)
    #expect(decoder.format == PCMFormat(sampleRate: 176_400, bitDepth: 24, channelCount: 1))
    #expect(decoder.totalFrames == 4)

    let buffer = PCMBuffer(channelCount: 1, capacity: 16)
    let read = try decoder.readFrames(into: buffer)
    #expect(read == 4)

    let expected: [Int32] = [
        DSDDecoder.pack24(marker: 0x05, high: 0x11, low: 0x22),
        DSDDecoder.pack24(marker: 0xFA, high: 0x33, low: 0x44),
        DSDDecoder.pack24(marker: 0x05, high: 0x55, low: 0x66),
        DSDDecoder.pack24(marker: 0xFA, high: 0x77, low: 0x88),
    ]
    for i in 0..<4 {
        #expect(buffer.channelData[0][i] == expected[i])
    }
}

@Test func stereoReadsPerChannelBlocksNotByteInterleaved() throws {
    let payload: [UInt8] = [0xAA, 0xBB, 0xCC, 0xDD]
    let url = try makeDSFFile(channelCount: 2, blockSizePerChannel: 2, dsdBitRate: 2_822_400, payload: payload)
    defer { try? FileManager.default.removeItem(at: url) }

    let decoder = try DSDDecoder(url: url)
    #expect(decoder.format.sampleRate == 176_400)
    #expect(decoder.format.channelCount == 2)

    let buffer = PCMBuffer(channelCount: 2, capacity: 4)
    let read = try decoder.readFrames(into: buffer)
    #expect(read == 1)

    #expect(buffer.channelData[0][0] == DSDDecoder.pack24(marker: 0x05, high: 0xAA, low: 0xBB))
    #expect(buffer.channelData[1][0] == DSDDecoder.pack24(marker: 0x05, high: 0xCC, low: 0xDD))
}

@Test func throwsForNonDSFFile() throws {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("not_a_dsf_\(UUID().uuidString).dsf")
    try Data("not a dsf file at all, just some bytes".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(throws: AudioDecoderError.self) {
        _ = try DSDDecoder(url: url)
    }
}

private func makeDSFFile(channelCount: Int, blockSizePerChannel: Int, dsdBitRate: UInt32, payload: [UInt8]) throws -> URL {
    var data = Data()

    func appendUInt32LE(_ value: UInt32) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    func appendUInt64LE(_ value: UInt64) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    data.append(contentsOf: Array("DSD ".utf8))
    appendUInt64LE(28)
    appendUInt64LE(UInt64(28 + 52 + 12 + payload.count))
    appendUInt64LE(0)

    data.append(contentsOf: Array("fmt ".utf8))
    appendUInt64LE(52)
    appendUInt32LE(1)
    appendUInt32LE(0)
    appendUInt32LE(channelCount == 1 ? 1 : 2)
    appendUInt32LE(UInt32(channelCount))
    appendUInt32LE(dsdBitRate)
    appendUInt32LE(1)
    appendUInt64LE(UInt64(payload.count / channelCount) * 8)
    appendUInt32LE(UInt32(blockSizePerChannel))
    appendUInt32LE(0)

    data.append(contentsOf: Array("data".utf8))
    appendUInt64LE(UInt64(12 + payload.count))
    data.append(contentsOf: payload)

    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_\(UUID().uuidString).dsf")
    try data.write(to: url)
    return url
}
