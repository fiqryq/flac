import Foundation
import Testing
@testable import FlacPlayerCore

private func fixture(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
}

@Test func detectsPeakNearKnownSineFrequency() throws {
    let decoder = try FLACDecoder(url: fixture("tone_44k16.flac"))
    let spectrogram = try SpectrogramAnalyzer.analyze(decoder: decoder)
    #expect(!spectrogram.columns.isEmpty)

    let rows = try #require(spectrogram.columns.first?.count)
    var averaged = [Float](repeating: 0, count: rows)
    for column in spectrogram.columns {
        for r in 0..<rows { averaged[r] += column[r] }
    }
    let peakRow = averaged.indices.max { averaged[$0] < averaged[$1] }!
    let rowHz = spectrogram.nyquistHz / Double(rows)
    let peakFrequency = Double(peakRow) * rowHz

    #expect(abs(peakFrequency - 440) < 150, "expected peak near 440Hz, got \(peakFrequency)Hz")
}

@Test func detectedCutoffMatchesToneFrequencyForPureSine() throws {
    let decoder = try FLACDecoder(url: fixture("tone_44k16.flac"))
    let spectrogram = try SpectrogramAnalyzer.analyze(decoder: decoder)
    let cutoff = try #require(spectrogram.detectedCutoffHz)

    #expect(abs(cutoff - 440) < 200, "expected cutoff near 440Hz, got \(cutoff)Hz")
}

@Test func analyzesHiResFileAtItsOwnSampleRate() throws {
    let decoder = try FLACDecoder(url: fixture("tone_96k24.flac"))
    let spectrogram = try SpectrogramAnalyzer.analyze(decoder: decoder)
    #expect(spectrogram.sampleRate == 96000)
    #expect(spectrogram.nyquistHz == 48000)
}

@Test func throwsForUnsupportedCodec() {
    #expect(throws: SpectrogramAnalyzerError.self) {
        _ = try SpectrogramAnalyzer.analyze(forCodec: "DSD", url: fixture("tone_44k16.flac"))
    }
}
