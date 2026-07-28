import FlacPlayerCore
import SwiftUI

struct TrackRow: View {
    let track: Track
    @State private var isHovering = false
    @State private var artwork: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            ArtworkThumbnail(image: artwork, size: 36, cornerRadius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                Text(track.artist)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(track.albumTitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 160, alignment: .leading)
                .lineLimit(1)
            Text(track.formatDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(track.durationDescription)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(isHovering ? 0.06 : 0))
        )
        .onHover { isHovering = $0 }
        .task(id: track.filePath) {
            artwork = await ArtworkCache.shared.load(for: track.filePath)
        }
    }
}
