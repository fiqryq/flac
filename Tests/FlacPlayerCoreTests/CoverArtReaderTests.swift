import Foundation
import Testing
@testable import FlacPlayerCore

private func fixture(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
}

@Test func readsEmbeddedFrontCoverFromFLAC() throws {
    let data = try #require(CoverArtReader.readCoverArt(url: fixture("tagged_with_art.flac")))
    #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
}

@Test func readsEmbeddedArtworkFromM4A() throws {
    let data = try #require(CoverArtReader.readCoverArt(url: fixture("tagged_with_art.m4a")))
    #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
}

@Test func returnsNilForFLACWithoutArtwork() {
    #expect(CoverArtReader.readCoverArt(url: fixture("tagged.flac")) == nil)
}

@Test func returnsNilForM4AWithoutArtwork() {
    #expect(CoverArtReader.readCoverArt(url: fixture("tagged.m4a")) == nil)
}

@Test func returnsNilForUnsupportedExtension() {
    #expect(CoverArtReader.readCoverArt(url: URL(fileURLWithPath: "/tmp/something.txt")) == nil)
}
