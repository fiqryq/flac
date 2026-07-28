import FlacPlayerCore
import SwiftData
import SwiftUI

struct AlbumDetailView: View {
    let albumID: PersistentIdentifier
    let onBack: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerModel.self) private var playerModel
    @Environment(InspectorModel.self) private var inspectorModel
    @State private var artwork: NSImage?
    @State private var searchText = ""

    var body: some View {
        if let album = modelContext.model(for: albumID) as? Album {
            let tracks = album.orderedTracks
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    backButton
                    header(for: album, tracks: tracks)
                    trackTable(tracks)
                }
            }
            .navigationTitle("")
            .searchable(text: $searchText, prompt: "Find in \(album.title)")
            .task(id: album.persistentModelID) {
                guard let firstPath = tracks.first?.filePath else { return }
                artwork = await ArtworkCache.shared.load(for: firstPath)
            }
        } else {
            ContentUnavailableView("Album not found", systemImage: "square.stack")
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Label("Albums", systemImage: "chevron.left")
        }
        .buttonStyle(.plain)
        .font(.callout.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func header(for album: Album, tracks: [Track]) -> some View {
        HStack(alignment: .top, spacing: 24) {
            ArtworkThumbnail(image: artwork, size: 200, cornerRadius: 8)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text(album.title)
                    .font(.system(size: 30, weight: .bold))
                Text(album.artist)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(summary(for: tracks))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        playerModel.play(tracks: tracks, startingAt: 0)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(minWidth: 70)
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .disabled(tracks.isEmpty)

                    Button {
                        playerModel.shuffle = true
                        playerModel.play(tracks: tracks, startingAt: 0)
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(minWidth: 70)
                    }
                    .buttonStyle(PillButtonStyle(prominent: false))
                    .disabled(tracks.isEmpty)
                }
                .padding(.top, 6)
            }
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(24)
    }

    private func summary(for tracks: [Track]) -> String {
        let songLabel = tracks.count == 1 ? "song" : "songs"
        let totalMinutes = Int(tracks.reduce(0) { $0 + $1.durationSeconds } / 60)
        return "\(tracks.count) \(songLabel), \(totalMinutes) min"
    }

    private func trackTable(_ tracks: [Track]) -> some View {
        VStack(spacing: 0) {
            AlbumColumnHeader()
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            ForEach(filteredIndexedTracks(tracks), id: \.1.persistentModelID) { index, track in
                AlbumTrackRow(index: index + 1, track: track)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        playerModel.play(tracks: tracks, startingAt: index)
                    }
                    .onTapGesture(count: 1) {
                        inspectorModel.track = track
                    }
                Divider()
                    .padding(.leading, 24)
            }
        }
        .padding(.bottom, 24)
    }

    private func filteredIndexedTracks(_ tracks: [Track]) -> [(Int, Track)] {
        let indexed = Array(tracks.enumerated())
        guard !searchText.isEmpty else { return indexed }
        return indexed.filter { _, track in
            track.title.localizedCaseInsensitiveContains(searchText)
                || track.artist.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct AlbumColumnHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("").frame(width: 24, alignment: .trailing)
            Text("Song")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Artist")
                .frame(width: 160, alignment: .leading)
            Text("Album")
                .frame(width: 160, alignment: .leading)
            Text("Time")
                .frame(width: 48, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
    }
}

private struct AlbumTrackRow: View {
    let index: Int
    let track: Track
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(track.title)
                .font(.body)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(track.artist)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
            Text(track.albumTitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
            Text(track.durationDescription)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 24)
        .background(Color.primary.opacity(isHovering ? 0.06 : 0))
        .onHover { isHovering = $0 }
    }
}

private struct PillButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .glassSurface(Capsule(), tint: prominent ? Color.flacAccent : nil, interactive: true)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
