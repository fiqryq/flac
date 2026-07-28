import FlacPlayerCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerModel.self) private var playerModel
    @Environment(InspectorModel.self) private var inspectorModel
    @Query(sort: [
        SortDescriptor(\Track.artist),
        SortDescriptor(\Track.albumTitle),
        SortDescriptor(\Track.trackNumber),
    ]) private var tracks: [Track]
    @State private var searchText = ""
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        List {
            ForEach(filteredTracks) { track in
                TrackRow(track: track)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        let index = filteredTracks.firstIndex(where: { $0.persistentModelID == track.persistentModelID }) ?? 0
                        playerModel.play(tracks: filteredTracks, startingAt: index)
                    }
                    .onTapGesture(count: 1) {
                        inspectorModel.track = track
                    }
            }
        }
        .searchable(text: $searchText, prompt: "Search title, artist, or album")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isImporting = true
                } label: {
                    Label("Add Files", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .help("Add Files…")
            }
        }
        .navigationTitle("")
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                addFiles(urls)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            addFiles(urls)
            return true
        }
        .alert("Couldn't add file", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private func addFiles(_ urls: [URL]) {
        for url in urls {
            do {
                _ = try LibraryScanner.addFile(at: url, context: modelContext)
            } catch {
                importError = "\(url.lastPathComponent): \(error)"
            }
        }
    }

    private var filteredTracks: [Track] {
        guard !searchText.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.artist.localizedCaseInsensitiveContains(searchText)
                || $0.albumTitle.localizedCaseInsensitiveContains(searchText)
        }
    }
}
