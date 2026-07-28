import AudioToolbox
import Foundation

public enum ExtAudioFileTagReader {
    public static func readTags(url: URL, fallbackTitle: String) -> AudioTags {
        var audioFile: AudioFileID?
        let openStatus = AudioFileOpenURL(url as CFURL, .readPermission, 0, &audioFile)
        guard openStatus == noErr, let audioFile else {
            return .fallback(fileName: fallbackTitle)
        }
        defer { AudioFileClose(audioFile) }

        var infoDict: Unmanaged<CFDictionary>?
        var size = UInt32(MemoryLayout<Unmanaged<CFDictionary>?>.size)
        let propertyStatus = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &size, &infoDict)
        guard propertyStatus == noErr,
              let dictionary = infoDict?.takeRetainedValue() as? [String: String] else {
            return .fallback(fileName: fallbackTitle)
        }

        return AudioTags(
            title: dictionary["title"] ?? fallbackTitle,
            artist: dictionary["artist"] ?? "Unknown Artist",
            albumTitle: dictionary["album"] ?? "Unknown Album",
            albumArtist: dictionary["artist"] ?? "Unknown Artist",
            trackNumber: dictionary["track number"].flatMap(leadingInt(from:)),
            discNumber: nil,
            year: dictionary["year"].flatMap { Int($0.prefix(4)) },
            genre: dictionary["genre"]
        )
    }
}
