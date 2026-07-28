import Foundation

public enum M3UPlaylist {
    public static func export(tracks: [Track], to url: URL) throws {
        var lines = ["#EXTM3U"]
        for track in tracks {
            let durationInt = Int(track.durationSeconds.rounded())
            lines.append("#EXTINF:\(durationInt),\(track.artist) - \(track.title)")
            lines.append(track.filePath)
        }
        let content = lines.joined(separator: "\n") + "\n"
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public static func importPaths(from url: URL) throws -> [String] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let baseDirectory = url.deletingLastPathComponent()
        var paths: [String] = []
        for rawLine in content.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            paths.append(resolvePath(line, baseDirectory: baseDirectory))
        }
        return paths
    }

    private static func resolvePath(_ line: String, baseDirectory: URL) -> String {
        if line.hasPrefix("/") {
            return line
        }
        return baseDirectory.appendingPathComponent(line).standardizedFileURL.path
    }
}
