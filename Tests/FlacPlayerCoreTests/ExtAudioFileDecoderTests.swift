import Foundation
import Testing
@testable import FlacPlayerCore

private func fixture(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
}

@Test func decodesALACWithCorrectSourceBitDepth() throws {
    let decoder = try ExtAudioFileDecoder(url: fixture("test_alac_24bit.m4a"))
    #expect(decoder.format == PCMFormat(sampleRate: 96000, bitDepth: 24, channelCount: 2))
}

@Test func alacSamplesMatchKnownSineWaveAt24Bit() throws {
    let decoder = try ExtAudioFileDecoder(url: fixture("test_alac_24bit.m4a"))
    let buffer = PCMBuffer(channelCount: 2, capacity: 48000)
    let read = try decoder.readFrames(into: buffer)
    #expect(read > 0)

    let maxAmplitude = Double(1 << 23) - 1
    let expectedPeak = 0.5 * maxAmplitude
    var observedPeak: Int32 = 0
    for i in 0..<read {
        observedPeak = max(observedPeak, abs(buffer.channelData[0][i]))
    }
    #expect(abs(Double(observedPeak) - expectedPeak) < expectedPeak * 0.02)
    #expect(buffer.channelData[0][0] == 0)
}

@Test func decodesWAV() throws {
    let decoder = try ExtAudioFileDecoder(url: fixture("test_pcm16.wav"))
    #expect(decoder.format == PCMFormat(sampleRate: 44100, bitDepth: 16, channelCount: 2))
    #expect(decoder.totalFrames == 44100)
}

@Test func decodesAIFF() throws {
    let decoder = try ExtAudioFileDecoder(url: fixture("test_pcm16.aiff"))
    #expect(decoder.format == PCMFormat(sampleRate: 44100, bitDepth: 16, channelCount: 2))
    #expect(decoder.totalFrames == 44100)
}

@Test func wavSamplesMatchKnownSineWave() throws {
    let decoder = try ExtAudioFileDecoder(url: fixture("test_pcm16.wav"))
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
}

@Test func wavReadsAcrossMultipleCalls() throws {
    let decoder = try ExtAudioFileDecoder(url: fixture("test_pcm16.wav"))
    let chunk = PCMBuffer(channelCount: 2, capacity: 4096)
    var totalRead = 0
    while true {
        let read = try decoder.readFrames(into: chunk)
        if read == 0 { break }
        totalRead += read
    }
    #expect(totalRead == 44100)
}

@Test func wavSeekMovesToRequestedFrame() throws {
    let decoder = try ExtAudioFileDecoder(url: fixture("test_pcm16.wav"))
    try decoder.seek(toFrame: 22050)
    let buffer = PCMBuffer(channelCount: 2, capacity: 1)
    let read = try decoder.readFrames(into: buffer)
    #expect(read == 1)
}

@Test func throwsForMissingExtAudioFile() {
    #expect(throws: (any Error).self) {
        _ = try ExtAudioFileDecoder(url: URL(fileURLWithPath: "/nonexistent/path/does-not-exist.wav"))
    }
}
