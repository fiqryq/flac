import FlacPlayerCore
import SwiftData
import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarSelection?
    @Query(sort: \Playlist.name) private var playlists: [Playlist]

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label {
                    Text("All Tracks")
                } icon: {
                    SidebarIconBadge(systemName: "music.note", color: .flacAccent)
                }
                .tag(SidebarSelection.library)

                Label {
                    Text("Albums")
                } icon: {
                    SidebarIconBadge(systemName: "square.stack.fill", color: .pink)
                }
                .tag(SidebarSelection.albums)

                Label {
                    Text("Watched Folders")
                } icon: {
                    SidebarIconBadge(systemName: "folder.fill", color: .blue)
                }
                .tag(SidebarSelection.watchedFolders)
            }

            Section("Playback") {
                Label {
                    Text("Equalizer")
                } icon: {
                    SidebarIconBadge(systemName: "slider.horizontal.3", color: .orange)
                }
                .tag(SidebarSelection.equalizer)

                Label {
                    Text("Signal Path")
                } icon: {
                    SidebarIconBadge(systemName: "waveform", color: .mint)
                }
                .tag(SidebarSelection.signalPath)

                Label {
                    Text("Spectrogram")
                } icon: {
                    SidebarIconBadge(systemName: "waveform.path.ecg", color: .teal)
                }
                .tag(SidebarSelection.spectrogram)
            }

            if !playlists.isEmpty {
                Section("Playlists") {
                    ForEach(playlists) { playlist in
                        Label {
                            Text(playlist.name)
                        } icon: {
                            SidebarIconBadge(systemName: "music.note.list", color: .purple)
                        }
                        .tag(SidebarSelection.playlist(playlist.persistentModelID))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("")
    }
}
