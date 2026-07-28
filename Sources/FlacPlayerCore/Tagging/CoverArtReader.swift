@preconcurrency import CFLAC
import AudioToolbox
import Foundation

public enum CoverArtReader {
    public static func readCoverArt(url: URL) -> Data? {
        switch url.pathExtension.lowercased() {
        case "flac":
            return readFLACCoverArt(url: url)
        case "m4a", "wav", "aiff", "aif":
            return readAudioFileCoverArt(url: url)
        default:
            return nil
        }
    }

    private static func readFLACCoverArt(url: URL) -> Data? {
        guard let iterator = FLAC__metadata_simple_iterator_new() else { return nil }
        defer { FLAC__metadata_simple_iterator_delete(iterator) }

        let cPath = strdup(url.path)
        defer { free(cPath) }
        guard FLAC__metadata_simple_iterator_init(iterator, cPath, 1, 0) != 0 else { return nil }

        var fallback: Data?
        repeat {
            guard FLAC__metadata_simple_iterator_get_block_type(iterator) == FLAC__METADATA_TYPE_PICTURE else {
                continue
            }
            guard let block = FLAC__metadata_simple_iterator_get_block(iterator) else { continue }
            defer { FLAC__metadata_object_delete(block) }

            let picture = block.pointee.data.picture
            guard let dataPointer = picture.data else { continue }
            let data = Data(bytes: dataPointer, count: Int(picture.data_length))

            if picture.type == FLAC__STREAM_METADATA_PICTURE_TYPE_FRONT_COVER {
                return data
            }
            if fallback == nil {
                fallback = data
            }
        } while FLAC__metadata_simple_iterator_next(iterator) != 0

        return fallback
    }

    private static func readAudioFileCoverArt(url: URL) -> Data? {
        var audioFile: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &audioFile) == noErr, let audioFile else {
            return nil
        }
        defer { AudioFileClose(audioFile) }

        var artworkData: Unmanaged<CFData>?
        var size = UInt32(MemoryLayout<Unmanaged<CFData>?>.size)
        let status = AudioFileGetProperty(audioFile, kAudioFilePropertyAlbumArtwork, &size, &artworkData)
        guard status == noErr, let data = artworkData?.takeRetainedValue() else { return nil }
        return data as Data
    }
}
