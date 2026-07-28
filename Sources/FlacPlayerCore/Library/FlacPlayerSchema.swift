import SwiftData

public enum FlacPlayerSchema {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(
            for: Track.self, Album.self, Playlist.self, PlaylistEntry.self, WatchedFolder.self,
            configurations: configuration
        )
    }
}
