import Foundation
import Testing
@testable import FlacPlayerCore

private func fixture(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
}

@Test func readsFullVorbisCommentTagSet() {
    let tags = TagReader.readTags(url: fixture("tagged.flac"))
    #expect(tags.title == "Test Title")
    #expect(tags.artist == "Test Artist")
    #expect(tags.albumTitle == "Test Album")
    #expect(tags.albumArtist == "Test Album Artist")
    #expect(tags.trackNumber == 3)
    #expect(tags.discNumber == 1)
    #expect(tags.year == 2023)
    #expect(tags.genre == "Electronic")
}

@Test func fallsBackToFileNameForUntaggedFLAC() {
    let tags = TagReader.readTags(url: fixture("tone_44k16.flac"))
    #expect(tags.title == "tone_44k16")
    #expect(tags.artist == "Unknown Artist")
}

@Test func readsInfoDictionaryTagsForM4A() {
    let tags = TagReader.readTags(url: fixture("tagged.m4a"))
    #expect(tags.title == "Test Title")
    #expect(tags.artist == "Test Artist")
    #expect(tags.albumTitle == "Test Album")
    #expect(tags.albumArtist == "Test Artist")
    #expect(tags.trackNumber == 3)
    #expect(tags.year == 2023)
    #expect(tags.genre == "Electronic")
}

@Test func fallsBackToFileNameForUntaggedWAV() {
    let tags = TagReader.readTags(url: fixture("test_pcm16.wav"))
    #expect(tags.title == "test_pcm16")
    #expect(tags.artist == "Unknown Artist")
}

@Test func fallsBackForUnknownExtension() {
    let tags = TagReader.readTags(url: URL(fileURLWithPath: "/tmp/something.xyz"))
    #expect(tags.title == "something")
}
