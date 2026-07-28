import Foundation
import SwiftData
import Testing
@testable import FlacPlayerCore

private func makeTrack(_ path: String, title: String, artist: String, album: String) -> Track {
    Track(
        filePath: path,
        title: title,
        artist: artist,
        albumTitle: album,
        albumArtist: artist,
        durationSeconds: 180,
        sampleRate: 44100,
        bitDepth: 16,
        channelCount: 2,
        codec: "FLAC"
    )
}

@Test func insertsAndFetchesTracks() throws {
    let container = try FlacPlayerSchema.makeContainer(inMemory: true)
    let context = ModelContext(container)

    let track = makeTrack("/music/song.flac", title: "Song", artist: "Artist", album: "Album")
    context.insert(track)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Track>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.filePath == "/music/song.flac")
}

@Test func trackFilePathIsUnique() throws {
    let container = try FlacPlayerSchema.makeContainer(inMemory: true)
    let context = ModelContext(container)

    context.insert(makeTrack("/music/dup.flac", title: "A", artist: "X", album: "Y"))
    context.insert(makeTrack("/music/dup.flac", title: "B", artist: "X", album: "Y"))
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Track>())
    #expect(fetched.count == 1)
}

@Test func albumGroupsItsTracks() throws {
    let container = try FlacPlayerSchema.makeContainer(inMemory: true)
    let context = ModelContext(container)

    let album = Album(title: "Album", artist: "Artist")
    context.insert(album)

    let track1 = makeTrack("/music/a1.flac", title: "One", artist: "Artist", album: "Album")
    let track2 = makeTrack("/music/a2.flac", title: "Two", artist: "Artist", album: "Album")
    track1.album = album
    track2.album = album
    context.insert(track1)
    context.insert(track2)
    try context.save()

    #expect(album.tracks.count == 2)
}

@Test func playlistPreservesExplicitOrderAcrossFetch() throws {
    let container = try FlacPlayerSchema.makeContainer(inMemory: true)
    let context = ModelContext(container)

    let trackC = makeTrack("/music/c.flac", title: "C", artist: "Artist", album: "Album")
    let trackA = makeTrack("/music/a.flac", title: "A", artist: "Artist", album: "Album")
    let trackB = makeTrack("/music/b.flac", title: "B", artist: "Artist", album: "Album")
    for track in [trackC, trackA, trackB] {
        context.insert(track)
    }

    let playlist = Playlist(name: "My Mix")
    context.insert(playlist)
    playlist.append(trackB, context: context)
    playlist.append(trackC, context: context)
    playlist.append(trackA, context: context)
    try context.save()

    let fetchedPlaylists = try context.fetch(FetchDescriptor<Playlist>())
    let fetched = try #require(fetchedPlaylists.first)
    #expect(fetched.orderedTracks.map(\.filePath) == ["/music/b.flac", "/music/c.flac", "/music/a.flac"])
}

@Test func playlistReorderUpdatesPositions() throws {
    let container = try FlacPlayerSchema.makeContainer(inMemory: true)
    let context = ModelContext(container)

    let trackA = makeTrack("/music/a.flac", title: "A", artist: "Artist", album: "Album")
    let trackB = makeTrack("/music/b.flac", title: "B", artist: "Artist", album: "Album")
    context.insert(trackA)
    context.insert(trackB)

    let playlist = Playlist(name: "Reorder Me")
    context.insert(playlist)
    playlist.append(trackA, context: context)
    playlist.append(trackB, context: context)

    playlist.reorder(to: [trackB, trackA], context: context)
    try context.save()

    #expect(playlist.orderedTracks.map(\.filePath) == ["/music/b.flac", "/music/a.flac"])
}

@Test func m3uExportThenImportRoundTripsAbsolutePaths() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let tracks = [
        makeTrack("/music/one.flac", title: "One", artist: "Artist", album: "Album"),
        makeTrack("/music/two.flac", title: "Two", artist: "Artist", album: "Album"),
    ]
    let playlistURL = tempDir.appendingPathComponent("mix.m3u8")
    try M3UPlaylist.export(tracks: tracks, to: playlistURL)

    let contents = try String(contentsOf: playlistURL, encoding: .utf8)
    #expect(contents.hasPrefix("#EXTM3U"))
    #expect(contents.contains("#EXTINF:180,Artist - One"))

    let importedPaths = try M3UPlaylist.importPaths(from: playlistURL)
    #expect(importedPaths == ["/music/one.flac", "/music/two.flac"])
}

@Test func m3uImportResolvesRelativePathsAgainstPlaylistDirectory() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("tracks"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let playlistURL = tempDir.appendingPathComponent("mix.m3u")
    let content = "#EXTM3U\n#EXTINF:120,Someone - Track\ntracks/song.flac\n"
    try content.write(to: playlistURL, atomically: true, encoding: .utf8)

    let importedPaths = try M3UPlaylist.importPaths(from: playlistURL)
    #expect(importedPaths == [tempDir.appendingPathComponent("tracks/song.flac").path])
}

@Test func watchedFolderPathIsUnique() throws {
    let container = try FlacPlayerSchema.makeContainer(inMemory: true)
    let context = ModelContext(container)

    context.insert(WatchedFolder(path: "/Users/test/Music"))
    context.insert(WatchedFolder(path: "/Users/test/Music"))
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<WatchedFolder>())
    #expect(fetched.count == 1)
}
