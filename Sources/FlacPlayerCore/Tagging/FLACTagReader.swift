@preconcurrency import CFLAC
import Foundation

public enum FLACTagReader {
    public static func readTags(url: URL, fallbackTitle: String) -> AudioTags {
        guard let iterator = FLAC__metadata_simple_iterator_new() else {
            return .fallback(fileName: fallbackTitle)
        }
        defer { FLAC__metadata_simple_iterator_delete(iterator) }

        let cPath = strdup(url.path)
        defer { free(cPath) }
        guard FLAC__metadata_simple_iterator_init(iterator, cPath, 1, 0) != 0 else {
            return .fallback(fileName: fallbackTitle)
        }

        var rawEntries: [String: String] = [:]
        repeat {
            guard FLAC__metadata_simple_iterator_get_block_type(iterator) == FLAC__METADATA_TYPE_VORBIS_COMMENT else {
                continue
            }
            guard let block = FLAC__metadata_simple_iterator_get_block(iterator) else { continue }
            defer { FLAC__metadata_object_delete(block) }

            let comment = block.pointee.data.vorbis_comment
            for i in 0..<Int(comment.num_comments) {
                let entry = comment.comments[i]
                guard let entryPointer = entry.entry else { continue }
                let raw = String(decoding: UnsafeBufferPointer(start: entryPointer, count: Int(entry.length)), as: UTF8.self)
                guard let equalsIndex = raw.firstIndex(of: "=") else { continue }
                let key = raw[raw.startIndex..<equalsIndex].uppercased()
                rawEntries[key] = String(raw[raw.index(after: equalsIndex)...])
            }
        } while FLAC__metadata_simple_iterator_next(iterator) != 0

        return AudioTags(
            title: rawEntries["TITLE"] ?? fallbackTitle,
            artist: rawEntries["ARTIST"] ?? "Unknown Artist",
            albumTitle: rawEntries["ALBUM"] ?? "Unknown Album",
            albumArtist: rawEntries["ALBUMARTIST"] ?? rawEntries["ARTIST"] ?? "Unknown Artist",
            trackNumber: rawEntries["TRACKNUMBER"].flatMap(leadingInt(from:)),
            discNumber: rawEntries["DISCNUMBER"].flatMap(leadingInt(from:)),
            year: rawEntries["DATE"].flatMap { Int($0.prefix(4)) },
            genre: rawEntries["GENRE"]
        )
    }
}
