import Foundation
import SwiftData
import Testing
@testable import FlacPlayerCore

private func fixture(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(name)
}

private func makeTempLibraryFolder() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("Nested"), withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: fixture("tagged.flac"), to: root.appendingPathComponent("tagged.flac"))
    try FileManager.default.copyItem(at: fixture("test_pcm16.wav"), to: root.appendingPathComponent("Nested/pcm.wav"))
    try "not audio".write(to: root.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)
    return root
}

@Test func findsAudioFilesRecursivelyAndIgnoresOtherFiles() throws {
    let root = try makeTempLibraryFolder()
    defer { try? FileManager.default.removeItem(at: root) }

    let found = Set(LibraryScanner.findAudioFiles(in: root).map(\.lastPathComponent))
    #expect(found == ["tagged.flac", "pcm.wav"])
}

@Test func scanInsertsTracksWithTagsAndFormat() throws {
    let root = try makeTempLibraryFolder()
    defer { try? FileManager.default.removeItem(at: root) }

    let container = try FlacPlayerSchema.makeContainer(inMemory: true)
    let context = ModelContext(container)

    let added = try LibraryScanner.scan(folder: root, context: context)
    #expect(added.count == 2)

    let flacTrack = try #require(added.first { $0.filePath.hasSuffix("tagged.flac") })
    #expect(flacTrack.title == "Test Title")
    #expect(flacTrack.codec == "FLAC")
    #expect(flacTrack.sampleRate == 44100)
    #expect(flacTrack.bitDepth == 16)
    #expect(flacTrack.album?.title == "Test Album")

    let wavTrack = try #require(added.first { $0.filePath.hasSuffix("pcm.wav") })
    #expect(wavTrack.codec == "PCM")
    #expect(abs(wavTrack.durationSeconds - 1.0) < 0.01)
}

@Test func scanIsIdempotent() throws {
    let root = try makeTempLibraryFolder()
    defer { try? FileManager.default.removeItem(at: root) }

    let container = try FlacPlayerSchema.makeContainer(inMemory: true)
    let context = ModelContext(container)

    let firstPass = try LibraryScanner.scan(folder: root, context: context)
    #expect(firstPass.count == 2)

    let secondPass = try LibraryScanner.scan(folder: root, context: context)
    #expect(secondPass.isEmpty)

    let allTracks = try context.fetch(FetchDescriptor<Track>())
    #expect(allTracks.count == 2)
}

@Test func addFileAddsASingleTrackOutsideAnyWatchedFolder() throws {
    let container = try FlacPlayerSchema.makeContainer(inMemory: true)
    let context = ModelContext(container)

    let track = try LibraryScanner.addFile(at: fixture("tagged.m4a"), context: context)
    #expect(track?.codec == "ALAC")
    #expect(track?.title == "Test Title")

    let again = try LibraryScanner.addFile(at: fixture("tagged.m4a"), context: context)
    #expect(again == nil)
}

@Test func addFileRejectsUnsupportedExtension() throws {
    let container = try FlacPlayerSchema.makeContainer(inMemory: true)
    let context = ModelContext(container)

    #expect(throws: LibraryScanError.self) {
        _ = try LibraryScanner.addFile(at: URL(fileURLWithPath: "/tmp/notaudio.txt"), context: context)
    }
}
