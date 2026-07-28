import Foundation
import SwiftData

@Model
public final class Album {
    public var title: String
    public var artist: String

    @Relationship(deleteRule: .nullify, inverse: \Track.album)
    public var tracks: [Track] = []

    public init(title: String, artist: String) {
        self.title = title
        self.artist = artist
    }

    public var orderedTracks: [Track] {
        tracks.sorted { lhs, rhs in
            let lhsDisc = lhs.discNumber ?? 0
            let rhsDisc = rhs.discNumber ?? 0
            if lhsDisc != rhsDisc { return lhsDisc < rhsDisc }
            return (lhs.trackNumber ?? 0) < (rhs.trackNumber ?? 0)
        }
    }
}
