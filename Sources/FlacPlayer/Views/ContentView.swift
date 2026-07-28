import FlacPlayerCore
import SwiftData
import SwiftUI

enum SidebarSelection: Hashable {
    case library
    case albums
    case watchedFolders
    case equalizer
    case signalPath
    case spectrogram
    case playlist(PersistentIdentifier)
}

struct ContentView: View {
    @Environment(PlayerModel.self) private var playerModel
    @State private var selection: SidebarSelection? = .library
    @State private var inspectorModel = InspectorModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            HStack(spacing: 0) {
                DetailView(selection: selection)
                    .frame(maxWidth: .infinity)

                if inspectorModel.track != nil {
                    Divider()
                    TrackInspectorView(track: inspectorModel.track)
                        .frame(width: 280)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: inspectorModel.track != nil)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                NowPlayingBar()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        inspectorModel.toggle(fallback: playerModel.currentTrack)
                    } label: {
                        Label("Track Info", systemImage: "sidebar.trailing")
                    }
                    .disabled(inspectorModel.track == nil
                        && inspectorModel.lastTrack == nil
                        && playerModel.currentTrack == nil)
                    .help(inspectorModel.track == nil ? "Show track info" : "Hide track info")
                }
            }
        }
        .environment(inspectorModel)
        .tint(.flacAccent)
        .frame(minWidth: 1000, minHeight: 520)
    }
}

private struct DetailView: View {
    let selection: SidebarSelection?

    var body: some View {
        switch selection {
        case .none, .library:
            LibraryView()
        case .albums:
            AlbumsView()
        case .watchedFolders:
            WatchedFoldersView()
        case .equalizer:
            EqualizerView()
        case .signalPath:
            SignalPathView()
        case .spectrogram:
            SpectrogramView()
        case .playlist(let id):
            PlaylistDetailView(playlistID: id)
        }
    }
}
