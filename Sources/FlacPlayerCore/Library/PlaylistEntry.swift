import Foundation
import SwiftData

@Model
public final class PlaylistEntry {
    public var position: Int
    public var track: Track?
    public var playlist: Playlist?

    public init(position: Int, track: Track, playlist: Playlist) {
        self.position = position
        self.track = track
        self.playlist = playlist
    }
}
