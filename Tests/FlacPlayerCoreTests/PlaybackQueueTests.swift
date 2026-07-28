import Testing
@testable import FlacPlayerCore

private func track(_ path: String) -> Track {
    Track(
        filePath: path, title: path, artist: "Artist", albumTitle: "Album", albumArtist: "Artist",
        durationSeconds: 180, sampleRate: 44100, bitDepth: 16, channelCount: 2, codec: "FLAC"
    )
}

private func paths(_ tracks: [Track]) -> [String] {
    tracks.map(\.filePath)
}

@Test func advancesInOrderWithRepeatOff() {
    var queue = PlaybackQueue(tracks: [track("a"), track("b"), track("c")])
    #expect(queue.start()?.filePath == "a")
    #expect(queue.advance()?.filePath == "b")
    #expect(queue.advance()?.filePath == "c")
    #expect(queue.advance() == nil)
    #expect(queue.currentTrack == nil)
}

@Test func repeatAllLoopsBackToStart() {
    var queue = PlaybackQueue(tracks: [track("a"), track("b")], repeatMode: .all)
    _ = queue.start()
    _ = queue.advance()
    #expect(queue.advance()?.filePath == "a")
    #expect(queue.advance()?.filePath == "b")
}

@Test func repeatOneStaysOnCurrentTrack() {
    var queue = PlaybackQueue(tracks: [track("a"), track("b")], repeatMode: .one)
    _ = queue.start()
    #expect(queue.advance()?.filePath == "a")
    #expect(queue.advance()?.filePath == "a")
}

@Test func retreatMovesBackward() {
    var queue = PlaybackQueue(tracks: [track("a"), track("b"), track("c")])
    _ = queue.start()
    _ = queue.advance()
    _ = queue.advance()
    #expect(queue.retreat()?.filePath == "b")
    #expect(queue.retreat()?.filePath == "a")
    #expect(queue.retreat() == nil)
}

@Test func retreatWrapsWithRepeatAll() {
    var queue = PlaybackQueue(tracks: [track("a"), track("b")], repeatMode: .all)
    _ = queue.start()
    #expect(queue.retreat()?.filePath == "b")
}

@Test func peekNextMatchesWhatAdvanceReturns() {
    var queue = PlaybackQueue(tracks: [track("a"), track("b"), track("c")], repeatMode: .all)
    _ = queue.start()
    #expect(queue.peekNext()?.filePath == queue.advance()?.filePath)
    #expect(queue.peekNext()?.filePath == queue.advance()?.filePath)
    #expect(queue.peekNext()?.filePath == queue.advance()?.filePath)
}

@Test func peekNextRespectsRepeatOne() {
    var queue = PlaybackQueue(tracks: [track("a"), track("b")], repeatMode: .one)
    _ = queue.start()
    #expect(queue.peekNext()?.filePath == "a")
}

@Test func peekNextIsNilAtEndWithRepeatOff() {
    var queue = PlaybackQueue(tracks: [track("a")])
    _ = queue.start()
    #expect(queue.peekNext() == nil)
}

@Test func shuffleVisitsEveryTrackExactlyOnce() {
    let allTracks = (0..<20).map { track("t\($0)") }
    var queue = PlaybackQueue(tracks: allTracks, shuffle: true)
    var visited: [String] = []
    var current = queue.start()
    while let track = current {
        visited.append(track.filePath)
        current = queue.advance()
    }
    #expect(Set(visited) == Set(paths(allTracks)))
    #expect(visited.count == allTracks.count)
}

@Test func togglingShufflePreservesCurrentTrack() {
    var queue = PlaybackQueue(tracks: [track("a"), track("b"), track("c"), track("d")])
    _ = queue.start()
    _ = queue.advance()
    let before = queue.currentTrack?.filePath
    queue.shuffle = true
    #expect(queue.currentTrack?.filePath == before)
    queue.shuffle = false
    #expect(queue.currentTrack?.filePath == before)
}

@Test func setTracksResetsPosition() {
    var queue = PlaybackQueue(tracks: [track("a"), track("b")])
    _ = queue.start()
    queue.setTracks([track("x"), track("y")])
    #expect(queue.currentTrack == nil)
    #expect(queue.start()?.filePath == "x")
}

@Test func emptyQueueStartsAndAdvancesToNil() {
    var queue = PlaybackQueue(tracks: [])
    #expect(queue.start() == nil)
    #expect(queue.advance() == nil)
}
