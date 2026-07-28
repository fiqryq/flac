import Foundation
import Testing
@testable import FlacPlayerCore

@Test func playsAudibleTestTone() throws {
    guard ProcessInfo.processInfo.environment["FLACPLAYER_LIVE_AUDIO_TEST"] != nil else {
        return
    }

    guard let device = try OutputDeviceCatalog.defaultOutputDevice() else {
        Issue.record("expected a default output device on this machine")
        return
    }

    let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent("tone_48k16.flac")

    let currentRate = try SampleRateSupport.currentNominalSampleRate(for: device.id)
    let decoder = try FLACDecoder(url: fixtureURL)
    #expect(abs(currentRate - decoder.format.sampleRate) < 1, "fixture must match the device's current rate for this manual test")

    let engine = BitPerfectOutputEngine()
    try engine.configure(device: device, decoder: decoder)
    try engine.start()
    Thread.sleep(forTimeInterval: 0.5)
    engine.stop()
}
