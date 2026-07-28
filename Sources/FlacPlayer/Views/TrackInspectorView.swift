import FlacPlayerCore
import SwiftUI

struct TrackInspectorView: View {
    let track: Track?
    @Environment(PlayerModel.self) private var playerModel
    @State private var artwork: NSImage?
    @State private var integrityResult: FLACIntegrityResult?
    @State private var isVerifying = false

    var body: some View {
        if let track {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ArtworkThumbnail(image: artwork, size: 160, cornerRadius: 12)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.title3.bold())
                        Text(track.artist)
                            .foregroundStyle(.secondary)
                        Text(track.albumTitle)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 14) {
                        field("Format", track.formatDescription)
                        field("Channels", track.channelDescription)
                        field("Duration", track.durationDescription)
                        if isCurrentlyPlaying {
                            field("Signal Path", playerModel.signalPathStatus.description)
                        }
                        if let trackNumber = track.trackNumber {
                            field("Track", trackPositionDescription(trackNumber))
                        }
                        if track.albumArtist != track.artist {
                            field("Album Artist", track.albumArtist)
                        }
                        if let year = track.year {
                            field("Year", String(year))
                        }
                        if let genre = track.genre {
                            field("Genre", genre)
                        }
                        field("Added", track.dateAdded.formatted(date: .abbreviated, time: .omitted))
                        field("File", (track.filePath as NSString).lastPathComponent)

                        if track.codec == "FLAC" {
                            integrityField(for: track)
                        }
                    }
                }
                .padding(20)
            }
            .task(id: track.filePath) {
                artwork = await ArtworkCache.shared.load(for: track.filePath)
                integrityResult = nil
                isVerifying = false
            }
        } else {
            ContentUnavailableView("No Track Selected", systemImage: "music.note")
        }
    }

    private var isCurrentlyPlaying: Bool {
        track?.persistentModelID == playerModel.currentTrack?.persistentModelID
    }

    private func trackPositionDescription(_ number: Int) -> String {
        guard let disc = track?.discNumber else { return "\(number)" }
        return "\(number) (Disc \(disc))"
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }

    @ViewBuilder
    private func integrityField(for track: Track) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Integrity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(integrityDescription)
                    .font(.body)
                    .foregroundStyle(integrityColor)
            }
            Spacer(minLength: 12)
            if isVerifying {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Verify") {
                    verifyIntegrity(of: track)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var integrityDescription: String {
        switch integrityResult {
        case .none:
            return "Not checked"
        case .verified:
            return "Verified — matches embedded checksum"
        case .mismatch:
            return "Mismatch — file may be corrupted"
        case .noChecksumStored:
            return "No checksum stored in file"
        case .decodeError(let message):
            return "Error: \(message)"
        }
    }

    private var integrityColor: Color {
        switch integrityResult {
        case .verified: return .green
        case .mismatch: return .red
        default: return .secondary
        }
    }

    private func verifyIntegrity(of track: Track) {
        isVerifying = true
        let path = track.filePath
        Task.detached(priority: .utility) {
            let result = FLACIntegrity.verify(url: URL(fileURLWithPath: path))
            await MainActor.run {
                integrityResult = result
                isVerifying = false
            }
        }
    }
}
