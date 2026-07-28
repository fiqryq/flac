import Foundation
import SwiftData

@Model
public final class Track {
    @Attribute(.unique) public var filePath: String

    public var title: String
    public var artist: String
    public var albumTitle: String
    public var albumArtist: String
    public var trackNumber: Int?
    public var discNumber: Int?
    public var year: Int?
    public var genre: String?
    public var durationSeconds: Double

    public var sampleRate: Double
    public var bitDepth: Int
    public var channelCount: Int
    public var codec: String

    public var dateAdded: Date

    public var album: Album?

    public init(
        filePath: String,
        title: String,
        artist: String,
        albumTitle: String,
        albumArtist: String,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        year: Int? = nil,
        genre: String? = nil,
        durationSeconds: Double,
        sampleRate: Double,
        bitDepth: Int,
        channelCount: Int,
        codec: String,
        dateAdded: Date = Date()
    ) {
        self.filePath = filePath
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.albumArtist = albumArtist
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.year = year
        self.genre = genre
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channelCount = channelCount
        self.codec = codec
        self.dateAdded = dateAdded
    }
}

public extension Track {
    var formatDescription: String {
        if codec == "DSD" {
            return dsdRateLabel
        }
        let khz = sampleRate / 1000
        let rateText = khz == khz.rounded() ? "\(Int(khz))kHz" : String(format: "%.1fkHz", khz)
        return "\(codec) \(bitDepth)-bit/\(rateText)"
    }

    private var dsdRateLabel: String {
        let dsdBitRate = sampleRate * 16
        let multiple = Int((dsdBitRate / 44100).rounded())
        return "DSD\(multiple)"
    }

    var durationDescription: String {
        let total = Int(durationSeconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var channelDescription: String {
        switch channelCount {
        case 1: return "Mono"
        case 2: return "Stereo"
        default: return "\(channelCount) channels"
        }
    }
}
