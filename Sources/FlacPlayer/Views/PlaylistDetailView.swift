import FlacPlayerCore
import SwiftData
import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerModel.self) private var playerModel
    @Environment(InspectorModel.self) private var inspectorModel

    var body: some View {
        if let playlist = modelContext.model(for: playlistID) as? Playlist {
            let orderedTracks = playlist.orderedTracks
            VStack(alignment: .leading, spacing: 0) {
                ContentHeader(title: playlist.name)
                List {
                    ForEach(orderedTracks) { track in
                        TrackRow(track: track)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                let index = orderedTracks.firstIndex(where: { $0.persistentModelID == track.persistentModelID }) ?? 0
                                playerModel.play(tracks: orderedTracks, startingAt: index)
                            }
                            .onTapGesture(count: 1) {
                                inspectorModel.track = track
                            }
                    }
                }
            }
            .navigationTitle("")
        } else {
            ContentUnavailableView("Playlist not found", systemImage: "music.note.list")
        }
    }
}
