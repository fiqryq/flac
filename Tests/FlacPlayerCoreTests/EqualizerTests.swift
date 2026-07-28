import Foundation
import Testing
@testable import FlacPlayerCore

private let sampleRate = 44100.0

private func sineWave(frequency: Double, count: Int) -> [Float] {
    (0..<count).map { i in
        Float(sin(2 * Double.pi * frequency * Double(i) / sampleRate))
    }
}

private func rms(_ samples: ArraySlice<Float>) -> Float {
    let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
    return (sumOfSquares / Float(samples.count)).squareRoot()
}

@Test func zeroDBGainIsNearIdentity() {
    let processor = EqualizerProcessor()
    processor.setChannelCount(1)
    processor.updateBands([EQBand(frequency: 1000, gainDB: 0, q: 1.0)], sampleRate: sampleRate)
    processor.setEnabled(true)

    let input = sineWave(frequency: 1000, count: 2000)
    let snapshot = processor.prepareForRenderPass()
    let output = input.map { processor.process($0, channel: 0, snapshot: snapshot) }

    for i in 500..<input.count {
        #expect(abs(output[i] - input[i]) < 0.001)
    }
}

@Test func boostAtTargetFrequencyIncreasesAmplitude() {
    let processor = EqualizerProcessor()
    processor.setChannelCount(1)
    processor.updateBands([EQBand(frequency: 1000, gainDB: 12, q: 1.0)], sampleRate: sampleRate)
    processor.setEnabled(true)

    let input = sineWave(frequency: 1000, count: 4000)
    let snapshot = processor.prepareForRenderPass()
    let output = input.map { processor.process($0, channel: 0, snapshot: snapshot) }

    let steadyStateInput = rms(input[1000...])
    let steadyStateOutput = rms(output[1000...])
    let ratio = steadyStateOutput / steadyStateInput

    let expectedRatio = Float(pow(10, 12.0 / 20.0))
    #expect(abs(ratio - expectedRatio) / expectedRatio < 0.1)
}

@Test func cutAtTargetFrequencyDecreasesAmplitude() {
    let processor = EqualizerProcessor()
    processor.setChannelCount(1)
    processor.updateBands([EQBand(frequency: 1000, gainDB: -12, q: 1.0)], sampleRate: sampleRate)
    processor.setEnabled(true)

    let input = sineWave(frequency: 1000, count: 4000)
    let snapshot = processor.prepareForRenderPass()
    let output = input.map { processor.process($0, channel: 0, snapshot: snapshot) }

    let steadyStateInput = rms(input[1000...])
    let steadyStateOutput = rms(output[1000...])
    #expect(steadyStateOutput < steadyStateInput)
}

@Test func disabledBypassesProcessingEntirely() {
    let processor = EqualizerProcessor()
    processor.setChannelCount(1)
    processor.updateBands([EQBand(frequency: 1000, gainDB: 18, q: 2.0)], sampleRate: sampleRate)
    processor.setEnabled(false)

    let input = sineWave(frequency: 1000, count: 200)
    let snapshot = processor.prepareForRenderPass()
    let output = input.map { processor.process($0, channel: 0, snapshot: snapshot) }

    #expect(output == input)
}

@Test func changingBandCountDoesNotCrashAcrossRenderPasses() {
    let processor = EqualizerProcessor()
    processor.setChannelCount(2)
    processor.setEnabled(true)

    processor.updateBands([EQBand(frequency: 200, gainDB: 4)], sampleRate: sampleRate)
    var snapshot = processor.prepareForRenderPass()
    for sample in sineWave(frequency: 200, count: 64) {
        _ = processor.process(sample, channel: 0, snapshot: snapshot)
        _ = processor.process(sample, channel: 1, snapshot: snapshot)
    }

    processor.updateBands(
        [EQBand(frequency: 100, gainDB: 2), EQBand(frequency: 1000, gainDB: -3), EQBand(frequency: 8000, gainDB: 5)],
        sampleRate: sampleRate
    )
    snapshot = processor.prepareForRenderPass()
    for sample in sineWave(frequency: 1000, count: 64) {
        _ = processor.process(sample, channel: 0, snapshot: snapshot)
        _ = processor.process(sample, channel: 1, snapshot: snapshot)
    }

    processor.updateBands([], sampleRate: sampleRate)
    snapshot = processor.prepareForRenderPass()
    for sample in sineWave(frequency: 1000, count: 64) {
        let output = processor.process(sample, channel: 0, snapshot: snapshot)
        #expect(output == sample)
    }
}

@Test func channelCountChangeRebuildsStateWithoutCrashing() {
    let processor = EqualizerProcessor()
    processor.setChannelCount(2)
    processor.updateBands([EQBand(frequency: 500, gainDB: 6)], sampleRate: sampleRate)
    processor.setEnabled(true)

    var snapshot = processor.prepareForRenderPass()
    _ = processor.process(0.5, channel: 0, snapshot: snapshot)
    _ = processor.process(0.5, channel: 1, snapshot: snapshot)

    processor.setChannelCount(1)
    snapshot = processor.prepareForRenderPass()
    _ = processor.process(0.5, channel: 0, snapshot: snapshot)
}
