import Foundation
import Testing
@testable import FlacPlayerCore

private func fixture(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
}

@Test func configuresAgainstRealDefaultDeviceWithoutPlaying() throws {
    guard let device = try OutputDeviceCatalog.defaultOutputDevice() else {
        Issue.record("expected a default output device on this machine")
        return
    }

    let currentRate = try SampleRateSupport.currentNominalSampleRate(for: device.id)
    guard abs(currentRate - 48000) < 1 else {
        return
    }

    let decoder = try FLACDecoder(url: fixture("tone_48k16.flac"))
    let engine = BitPerfectOutputEngine()
    try engine.configure(device: device, decoder: decoder)
    engine.stop()
}
