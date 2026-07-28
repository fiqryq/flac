import Foundation

public enum TagReader {
    public static func readTags(url: URL) -> AudioTags {
        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        switch url.pathExtension.lowercased() {
        case "flac":
            return FLACTagReader.readTags(url: url, fallbackTitle: fallbackTitle)
        case "m4a", "wav", "aiff", "aif":
            return ExtAudioFileTagReader.readTags(url: url, fallbackTitle: fallbackTitle)
        default:
            return .fallback(fileName: fallbackTitle)
        }
    }
}
