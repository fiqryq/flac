import AppKit
import FlacPlayerCore
import Foundation
import MediaPlayer
import Observation

enum SignalPathStatus {
    case idle
    case bitPerfect(format: PCMFormat)
    case notBitPerfect(format: PCMFormat, reason: String)

    var description: String {
        switch self {
        case .idle:
            return "Not playing"
        case .bitPerfect(let format):
            return "\(Self.formatDescription(format)) → Direct, bit-perfect"
        case .notBitPerfect(let format, let reason):
            return "\(Self.formatDescription(format)) → \(reason)"
        }
    }

    var isBitPerfect: Bool {
        if case .bitPerfect = self { return true }
        return false
    }

    private static func formatDescription(_ format: PCMFormat) -> String {
        let khz = format.sampleRate / 1000
        let rateText = khz == khz.rounded() ? "\(Int(khz))kHz" : String(format: "%.1fkHz", khz)
        return "\(format.bitDepth)-bit/\(rateText)"
    }
}

@Observable
@MainActor
final class PlayerModel {
    private let controller: PlaybackController

    private(set) var currentTrack: Track? {
        didSet { updateNowPlayingInfo() }
    }
    private(set) var isPlaying = false {
        didSet { updateNowPlayingInfo() }
    }
    private(set) var currentArtwork: NSImage? {
        didSet { updateNowPlayingInfo() }
    }
    private(set) var availableDevices: [OutputDevice] = []
    var selectedDevice: OutputDevice?
    private(set) var lastError: String?

    private(set) var currentTime: Double = 0
    var duration: Double { currentTrack?.durationSeconds ?? 0 }

    private(set) var recentLevels: [Float] = []
    private static let levelHistoryCapacity = 100

    var volume: Float = UserDefaults.standard.object(forKey: "appVolume") as? Float ?? 1.0 {
        didSet {
            UserDefaults.standard.set(volume, forKey: "appVolume")
            controller.setVolume(volume)
        }
    }

    var shuffle = false {
        didSet { controller.setShuffle(shuffle) }
    }
    var repeatMode: RepeatMode = .off {
        didSet { controller.setRepeatMode(repeatMode) }
    }

    var eqEnabled: Bool = UserDefaults.standard.bool(forKey: "eqEnabled") {
        didSet {
            UserDefaults.standard.set(eqEnabled, forKey: "eqEnabled")
            controller.setEqualizer(bands: eqBands, enabled: eqEnabled)
        }
    }
    var eqBands: [EQBand] = PlayerModel.loadEQBands() {
        didSet {
            PlayerModel.saveEQBands(eqBands)
            controller.setEqualizer(bands: eqBands, enabled: eqEnabled)
        }
    }

    init() {
        controller = PlaybackController(queue: PlaybackQueue())
        controller.onTrackChanged = { [weak self] track in
            Task { @MainActor in
                self?.currentTrack = track
                self?.isPlaying = true
                self?.currentTime = 0
                self?.loadArtwork(for: track)
            }
        }
        controller.onQueueExhausted = { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
                self?.currentTrack = nil
                self?.currentArtwork = nil
                self?.currentTime = 0
            }
        }
        refreshDevices()
        controller.setVolume(volume)
        controller.setEqualizer(bands: eqBands, enabled: eqEnabled)
        setUpRemoteCommands()
        startProgressPolling()
    }

    func seek(to seconds: Double) {
        guard currentTrack != nil else { return }
        controller.seek(toSeconds: seconds)
        currentTime = seconds
    }

    private func startProgressPolling() {
        Task { [weak self] in
            while true {
                guard let self else { return }
                if self.isPlaying {
                    self.currentTime = self.controller.elapsedSeconds
                    self.pushLevel(self.controller.outputPeakLevel)
                } else {
                    self.pushLevel(0)
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func pushLevel(_ level: Float) {
        recentLevels.append(level)
        if recentLevels.count > Self.levelHistoryCapacity {
            recentLevels.removeFirst(recentLevels.count - Self.levelHistoryCapacity)
        }
    }

    func setGain(forBandAt index: Int, gainDB: Double) {
        guard eqBands.indices.contains(index) else { return }
        eqBands[index].gainDB = min(max(gainDB, -12), 12)
    }

    func applyPreset(_ preset: EQPreset) {
        for (index, gain) in preset.gains.enumerated() where eqBands.indices.contains(index) {
            eqBands[index].gainDB = gain
        }
    }

    func resetEQ() {
        applyPreset(.flat)
    }

    var currentPresetName: String {
        EQPreset.all.first { $0.gains == eqBands.map(\.gainDB) }?.name ?? "Custom"
    }

    private static let defaultEQBands: [EQBand] = EqualizerBands.frequencies.map {
        EQBand(frequency: $0, q: 1.0)
    }

    private static func loadEQBands() -> [EQBand] {
        guard let data = UserDefaults.standard.data(forKey: "eqBands"),
              let bands = try? JSONDecoder().decode([EQBand].self, from: data),
              bands.map(\.frequency) == EqualizerBands.frequencies else {
            return defaultEQBands
        }
        return bands
    }

    private static func saveEQBands(_ bands: [EQBand]) {
        guard let data = try? JSONEncoder().encode(bands) else { return }
        UserDefaults.standard.set(data, forKey: "eqBands")
    }

    private func loadArtwork(for track: Track) {
        currentArtwork = nil
        let path = track.filePath
        Task.detached(priority: .utility) { [weak self] in
            let data = CoverArtReader.readCoverArt(url: URL(fileURLWithPath: path))
            let image = data.flatMap { NSImage(data: $0) }
            await MainActor.run {
                guard let self, self.currentTrack?.filePath == path else { return }
                self.currentArtwork = image
            }
        }
    }

    private func setUpRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == false { self?.togglePlayPause() }
            }
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == true { self?.togglePlayPause() }
            }
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.albumTitle,
            MPMediaItemPropertyPlaybackDuration: track.durationSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]
        if let artwork = currentArtwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size, requestHandler: Self.artworkProvider(for: artwork))
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    nonisolated private static func artworkProvider(for image: NSImage) -> (CGSize) -> NSImage {
        { _ in image }
    }

    func refreshDevices() {
        do {
            availableDevices = try OutputDeviceCatalog.listOutputDevices()
            if selectedDevice == nil || !availableDevices.contains(selectedDevice!) {
                selectedDevice = try OutputDeviceCatalog.defaultOutputDevice()
            }
        } catch {
            lastError = "\(error)"
        }
    }

    func play(tracks: [Track], startingAt index: Int = 0) {
        guard let device = selectedDevice else {
            lastError = "No output device selected"
            return
        }
        guard !tracks.isEmpty else { return }
        let reordered = index > 0 && index < tracks.count
            ? Array(tracks[index...]) + Array(tracks[..<index])
            : tracks
        controller.setTracks(reordered)
        do {
            try controller.play(on: device)
        } catch {
            lastError = "\(error)"
        }
    }

    func togglePlayPause() {
        guard currentTrack != nil else { return }
        do {
            if isPlaying {
                controller.pause()
                isPlaying = false
            } else {
                try controller.resume()
                isPlaying = true
            }
        } catch {
            lastError = "\(error)"
        }
    }

    func next() {
        do { try controller.skipToNext() } catch { lastError = "\(error)" }
    }

    func previous() {
        do { try controller.skipToPrevious() } catch { lastError = "\(error)" }
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    var signalPathStatus: SignalPathStatus {
        guard let format = controller.playingFormat, let device = controller.currentDevice else {
            return .idle
        }
        var reasons: [String] = []
        if let deviceRate = try? SampleRateSupport.currentNominalSampleRate(for: device.id),
           abs(deviceRate - format.sampleRate) >= 1 {
            reasons.append("device at \(Int(deviceRate)) Hz (resampled)")
        }
        if abs(volume - 1.0) > 0.001 {
            reasons.append("volume attenuated")
        }
        if eqEnabled {
            reasons.append("EQ active")
        }
        guard reasons.isEmpty else {
            return .notBitPerfect(format: format, reason: reasons.joined(separator: ", "))
        }
        return .bitPerfect(format: format)
    }
}
