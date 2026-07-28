import Foundation

public enum PlaybackControllerError: Error, Equatable {
    case noTrack
    case unsupportedCodec(String)
}

public final class PlaybackController {
    private let engine = BitPerfectOutputEngine()
    public private(set) var queue: PlaybackQueue
    private var device: OutputDevice?
    private var currentFormat: PCMFormat?
    private var eqBands: [EQBand] = []
    private var eqEnabled = false
    private var volume: Float = 1.0
    private var isPlayingDSD = false
    private var trackStartFrame: UInt64 = 0

    public var playingFormat: PCMFormat? { currentFormat }
    public var currentDevice: OutputDevice? { device }

    public var outputPeakLevel: Float { engine.peakLevel }

    public var elapsedSeconds: Double {
        guard let format = currentFormat else { return 0 }
        let played = engine.playedFrames
        let frames = played >= trackStartFrame ? played - trackStartFrame : 0
        return Double(frames) / format.sampleRate
    }

    public func seek(toSeconds seconds: Double) {
        guard let format = currentFormat else { return }
        let targetFrame = UInt64(max(0, seconds) * format.sampleRate)
        trackStartFrame = 0
        engine.seek(toFrame: targetFrame)
    }

    public var onQueueExhausted: (() -> Void)?

    public var onTrackChanged: ((Track) -> Void)?

    public init(queue: PlaybackQueue) {
        self.queue = queue
    }

    public func play(on device: OutputDevice) throws {
        self.device = device
        guard let track = queue.currentTrack ?? queue.start() else {
            throw PlaybackControllerError.noTrack
        }
        try startPlayback(of: track, on: device)
    }

    public func skipToNext() throws {
        guard let device else { return }
        guard let track = queue.advance() else {
            onQueueExhausted?()
            return
        }
        try startPlayback(of: track, on: device)
    }

    public func skipToPrevious() throws {
        guard let device else { return }
        guard let track = queue.retreat() else { return }
        try startPlayback(of: track, on: device)
    }

    public func stop() {
        engine.stop()
        device = nil
        currentFormat = nil
        isPlayingDSD = false
    }

    public func setVolume(_ volume: Float) {
        self.volume = volume
        guard !isPlayingDSD else { return }
        engine.setGain(volume)
    }

    public func setEqualizer(bands: [EQBand], enabled: Bool) {
        eqBands = bands
        eqEnabled = enabled
        guard !isPlayingDSD, let format = currentFormat else { return }
        engine.updateEqualizerBands(bands, sampleRate: format.sampleRate)
        engine.setEqualizerEnabled(enabled)
    }

    public func setShuffle(_ enabled: Bool) {
        queue.shuffle = enabled
    }

    public func setRepeatMode(_ mode: RepeatMode) {
        queue.repeatMode = mode
    }

    public func setTracks(_ tracks: [Track]) {
        queue.setTracks(tracks)
    }

    public func pause() {
        engine.pause()
    }

    public func resume() throws {
        try engine.resume()
    }

    private func startPlayback(of track: Track, on device: OutputDevice) throws {
        let decoder = try Self.makeDecoder(for: track)
        try matchSampleRate(of: decoder.format, on: device)
        currentFormat = decoder.format
        isPlayingDSD = track.codec == "DSD"

        try engine.configure(
            device: device,
            decoder: decoder,
            nextDecoderProvider: { [weak self] in self?.provideNextForGapless() },
            onFinished: { [weak self] in self?.handleDecodeWorkerFinished() }
        )
        if isPlayingDSD {
            engine.setGain(1.0)
            engine.setEqualizerEnabled(false)
        } else {
            engine.setGain(volume)
            engine.updateEqualizerBands(eqBands, sampleRate: decoder.format.sampleRate)
            engine.setEqualizerEnabled(eqEnabled)
        }
        trackStartFrame = 0
        try engine.start()
        onTrackChanged?(track)
    }

    private func provideNextForGapless() -> AudioDecoder? {
        guard let nextTrack = queue.peekNext(),
              let nextDecoder = try? Self.makeDecoder(for: nextTrack),
              nextDecoder.format == currentFormat
        else {
            return nil
        }
        currentFormat = nextDecoder.format
        isPlayingDSD = nextTrack.codec == "DSD"
        if isPlayingDSD {
            engine.setGain(1.0)
            engine.setEqualizerEnabled(false)
        } else {
            engine.setGain(volume)
            engine.updateEqualizerBands(eqBands, sampleRate: nextDecoder.format.sampleRate)
            engine.setEqualizerEnabled(eqEnabled)
        }
        trackStartFrame = engine.playedFrames
        queue.advance()
        onTrackChanged?(nextTrack)
        return nextDecoder
    }

    private func handleDecodeWorkerFinished() {
        guard let device else { return }
        guard let track = queue.advance() else {
            onQueueExhausted?()
            return
        }
        try? startPlayback(of: track, on: device)
    }

    private func matchSampleRate(of format: PCMFormat, on device: OutputDevice) throws {
        guard try SampleRateSupport.supports(sampleRate: format.sampleRate, deviceID: device.id) else { return }
        try SampleRateSupport.setNominalSampleRate(format.sampleRate, for: device.id)
    }

    private static func makeDecoder(for track: Track) throws -> AudioDecoder {
        switch track.codec {
        case "FLAC":
            return try FLACDecoder(url: URL(fileURLWithPath: track.filePath))
        case "ALAC", "PCM":
            return try ExtAudioFileDecoder(url: URL(fileURLWithPath: track.filePath))
        case "DSD":
            return try DSDDecoder(url: URL(fileURLWithPath: track.filePath))
        default:
            throw PlaybackControllerError.unsupportedCodec(track.codec)
        }
    }
}
