import Foundation

public struct AudioTags: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var albumTitle: String
    public var albumArtist: String
    public var trackNumber: Int?
    public var discNumber: Int?
    public var year: Int?
    public var genre: String?

    public init(
        title: String,
        artist: String,
        albumTitle: String,
        albumArtist: String,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        year: Int? = nil,
        genre: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.albumArtist = albumArtist
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.year = year
        self.genre = genre
    }

    public static func fallback(fileName: String) -> AudioTags {
        AudioTags(title: fileName, artist: "Unknown Artist", albumTitle: "Unknown Album", albumArtist: "Unknown Artist")
    }
}

func leadingInt(from value: String) -> Int? {
    let firstComponent = value.split(separator: "/").first.map(String.init) ?? value
    return Int(firstComponent.trimmingCharacters(in: .whitespaces))
}
