import FlacPlayerCore
import SwiftData
import SwiftUI

struct AlbumsView: View {
    @Query(sort: [
        SortDescriptor(\Album.artist),
        SortDescriptor(\Album.title),
    ]) private var albums: [Album]
    @State private var searchText = ""
    @State private var selectedAlbumID: PersistentIdentifier?

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24)]

    var body: some View {
        Group {
            if let selectedAlbumID {
                AlbumDetailView(albumID: selectedAlbumID) {
                    self.selectedAlbumID = nil
                }
            } else {
                browseContent
            }
        }
        .navigationTitle("")
    }

    private var browseContent: some View {
        Group {
            if filteredAlbums.isEmpty {
                ContentUnavailableView(
                    albums.isEmpty ? "No Albums" : "No Results",
                    systemImage: albums.isEmpty ? "square.stack" : "magnifyingglass"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                        ForEach(filteredAlbums) { album in
                            Button {
                                selectedAlbumID = album.persistentModelID
                            } label: {
                                AlbumGridCard(album: album)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search albums or artists")
    }

    private var filteredAlbums: [Album] {
        guard !searchText.isEmpty else { return albums }
        return albums.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct AlbumGridCard: View {
    let album: Album
    @State private var artwork: NSImage?
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArtworkThumbnail(image: artwork, size: 168, cornerRadius: 8)
                .shadow(color: .black.opacity(0.2), radius: isHovering ? 10 : 6, y: isHovering ? 6 : 3)
                .scaleEffect(isHovering ? 1.02 : 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(album.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(album.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 168, alignment: .leading)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .task(id: album.persistentModelID) {
            guard let firstPath = album.orderedTracks.first?.filePath else { return }
            artwork = await ArtworkCache.shared.load(for: firstPath)
        }
    }
}
