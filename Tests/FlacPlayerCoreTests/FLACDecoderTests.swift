import Foundation
import Testing
@testable import FlacPlayerCore

private func fixture(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
}

@Test func decodesStandardResolutionFormat() throws {
    let decoder = try FLACDecoder(url: fixture("tone_44k16.flac"))
    #expect(decoder.format == PCMFormat(sampleRate: 44100, bitDepth: 16, channelCount: 2))
    #expect(decoder.totalFrames == 44100)
}

@Test func decodesHiResFormat() throws {
    let decoder = try FLACDecoder(url: fixture("tone_96k24.flac"))
    #expect(decoder.format == PCMFormat(sampleRate: 96000, bitDepth: 24, channelCount: 2))
    #expect(decoder.totalFrames == 48000)
}

@Test func readsAllFramesAcrossMultipleBlocks() throws {
    let decoder = try FLACDecoder(url: fixture("tone_44k16.flac"))
    let chunk = PCMBuffer(channelCount: 2, capacity: 4096)
    var totalRead = 0
    while true {
        let read = try decoder.readFrames(into: chunk)
        if read == 0 { break }
        totalRead += read
    }
    #expect(totalRead == 44100)
}

@Test func decodedSamplesMatchKnownSineWave() throws {
    let decoder = try FLACDecoder(url: fixture("tone_44k16.flac"))
    let buffer = PCMBuffer(channelCount: 2, capacity: 44100)
    let read = try decoder.readFrames(into: buffer)
    #expect(read == 44100)

    let maxAmplitude = Double(Int16.max)
    let expectedPeak = 0.5 * maxAmplitude
    var observedPeak: Int32 = 0
    for i in 0..<read {
        observedPeak = max(observedPeak, abs(buffer.channelData[0][i]))
    }
    #expect(abs(Double(observedPeak) - expectedPeak) < expectedPeak * 0.02)

    #expect(buffer.channelData[0][0] == 0)
    #expect(buffer.channelData[0][100] == buffer.channelData[1][100])
}

@Test func seekMovesToRequestedFrame() throws {
    let decoder = try FLACDecoder(url: fixture("tone_44k16.flac"))
    try decoder.seek(toFrame: 22050)
    let buffer = PCMBuffer(channelCount: 2, capacity: 1)
    let read = try decoder.readFrames(into: buffer)
    #expect(read == 1)
}

@Test func throwsForMissingFile() {
    #expect(throws: AudioDecoderError.self) {
        _ = try FLACDecoder(url: URL(fileURLWithPath: "/nonexistent/path/does-not-exist.flac"))
    }
}
