import Foundation
import SwiftData

public enum LibraryScanError: Error, Equatable {
    case unsupportedFormat(String)
}

public enum LibraryScanner {
    static let supportedExtensions: Set<String> = ["flac", "m4a", "wav", "aiff", "aif", "dsf"]

    public static func findAudioFiles(in folderURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        var results: [URL] = []
        for case let url as URL in enumerator {
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            results.append(url)
        }
        return results
    }

    @discardableResult
    public static func scan(folder folderURL: URL, context: ModelContext) throws -> [Track] {
        var added: [Track] = []
        for url in findAudioFiles(in: folderURL) {
            let path = url.path
            var descriptor = FetchDescriptor<Track>(predicate: #Predicate { $0.filePath == path })
            descriptor.fetchLimit = 1
            guard try context.fetch(descriptor).isEmpty else { continue }
            guard let track = try? makeTrack(for: url) else { continue }

            context.insert(track)
            attach(track, toAlbumMatching: track.albumTitle, artist: track.albumArtist, context: context)
            added.append(track)
        }
        if !added.isEmpty {
            try context.save()
        }
        return added
    }

    @discardableResult
    public static func addFile(at url: URL, context: ModelContext) throws -> Track? {
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
            throw LibraryScanError.unsupportedFormat(url.pathExtension)
        }
        let path = url.path
        var descriptor = FetchDescriptor<Track>(predicate: #Predicate { $0.filePath == path })
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return nil }

        let track = try makeTrack(for: url)
        context.insert(track)
        attach(track, toAlbumMatching: track.albumTitle, artist: track.albumArtist, context: context)
        try context.save()
        return track
    }

    private static func makeTrack(for url: URL) throws -> Track {
        let tags = TagReader.readTags(url: url)
        let format: PCMFormat
        let totalFrames: UInt64?
        let codec: String

        switch url.pathExtension.lowercased() {
        case "flac":
            let decoder = try FLACDecoder(url: url)
            format = decoder.format
            totalFrames = decoder.totalFrames
            codec = "FLAC"
        case "m4a":
            let decoder = try ExtAudioFileDecoder(url: url)
            format = decoder.format
            totalFrames = decoder.totalFrames
            codec = "ALAC"
        case "wav", "aiff", "aif":
            let decoder = try ExtAudioFileDecoder(url: url)
            format = decoder.format
            totalFrames = decoder.totalFrames
            codec = "PCM"
        case "dsf":
            let decoder = try DSDDecoder(url: url)
            format = decoder.format
            totalFrames = decoder.totalFrames
            codec = "DSD"
        default:
            throw LibraryScanError.unsupportedFormat(url.pathExtension)
        }

        let duration = totalFrames.map { Double($0) / format.sampleRate } ?? 0

        return Track(
            filePath: url.path,
            title: tags.title,
            artist: tags.artist,
            albumTitle: tags.albumTitle,
            albumArtist: tags.albumArtist,
            trackNumber: tags.trackNumber,
            discNumber: tags.discNumber,
            year: tags.year,
            genre: tags.genre,
            durationSeconds: duration,
            sampleRate: format.sampleRate,
            bitDepth: format.bitDepth,
            channelCount: format.channelCount,
            codec: codec
        )
    }

    private static func attach(_ track: Track, toAlbumMatching title: String, artist: String, context: ModelContext) {
        var descriptor = FetchDescriptor<Album>(predicate: #Predicate { $0.title == title && $0.artist == artist })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            track.album = existing
        } else {
            let album = Album(title: title, artist: artist)
            context.insert(album)
            track.album = album
        }
    }
}
