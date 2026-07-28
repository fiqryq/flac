import AppKit
import FlacPlayerCore
import Foundation

@MainActor
final class ArtworkCache {
    static let shared = ArtworkCache()

    private var images: [String: NSImage] = [:]
    private init() {}

    func load(for path: String) async -> NSImage? {
        if let cached = images[path] {
            return cached
        }
        let image = await Task.detached(priority: .utility) {
            CoverArtReader.readCoverArt(url: URL(fileURLWithPath: path)).flatMap { NSImage(data: $0) }
        }.value
        if let image {
            images[path] = image
        }
        return image
    }
}
