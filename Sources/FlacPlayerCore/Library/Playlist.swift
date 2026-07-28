import Foundation
import SwiftData

@Model
public final class Playlist {
    @Attribute(.unique) public var name: String
    public var dateCreated: Date
    public var dateModified: Date

    @Relationship(deleteRule: .cascade, inverse: \PlaylistEntry.playlist)
    public var entries: [PlaylistEntry] = []

    public init(name: String) {
        self.name = name
        self.dateCreated = Date()
        self.dateModified = Date()
    }

    public var orderedTracks: [Track] {
        entries.sorted { $0.position < $1.position }.compactMap { $0.track }
    }

    public func append(_ track: Track, context: ModelContext) {
        let entry = PlaylistEntry(position: entries.count, track: track, playlist: self)
        context.insert(entry)
        entries.append(entry)
        dateModified = Date()
    }

    public func reorder(to newOrder: [Track], context: ModelContext) {
        for entry in entries {
            guard let track = entry.track, let newIndex = newOrder.firstIndex(where: { $0.filePath == track.filePath }) else { continue }
            entry.position = newIndex
        }
        dateModified = Date()
    }
}
