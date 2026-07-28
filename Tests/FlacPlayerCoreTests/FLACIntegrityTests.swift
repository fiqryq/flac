import Foundation
import Testing
@testable import FlacPlayerCore

private func fixture(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
}

@Test func verifiesIntactFile() {
    #expect(FLACIntegrity.verify(url: fixture("tone_44k16.flac")) == .verified)
    #expect(FLACIntegrity.verify(url: fixture("tone_96k24.flac")) == .verified)
}

@Test func detectsCorruptedAudioData() throws {
    var data = try Data(contentsOf: fixture("tone_44k16.flac"))
    let flipIndex = data.count / 2
    data[flipIndex] ^= 0xFF

    let corrupted = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("corrupted_\(UUID().uuidString).flac")
    try data.write(to: corrupted)
    defer { try? FileManager.default.removeItem(at: corrupted) }

    let result = FLACIntegrity.verify(url: corrupted)
    let isDetected: Bool
    if case .mismatch = result {
        isDetected = true
    } else if case .decodeError = result {
        isDetected = true
    } else {
        isDetected = false
    }
    #expect(isDetected, "expected corruption to be detected, got \(result)")
}

@Test func reportsErrorForMissingFile() {
    let result = FLACIntegrity.verify(url: URL(fileURLWithPath: "/nonexistent/path/does-not-exist.flac"))
    #expect(result == .decodeError("error opening file"))
}
