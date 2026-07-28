public enum RepeatMode: Sendable {
    case off
    case one
    case all
}

public struct PlaybackQueue {
    public private(set) var tracks: [Track]
    public var repeatMode: RepeatMode

    public var shuffle: Bool {
        didSet {
            guard shuffle != oldValue else { return }
            rebuildOrder()
        }
    }

    private var order: [Int]
    private var position: Int?

    public init(tracks: [Track] = [], shuffle: Bool = false, repeatMode: RepeatMode = .off) {
        self.tracks = tracks
        self.repeatMode = repeatMode
        self.shuffle = shuffle
        self.order = Array(tracks.indices)
        self.position = nil
        if shuffle {
            order.shuffle()
        }
    }

    public var currentTrack: Track? {
        guard let position, order.indices.contains(position) else { return nil }
        return tracks[order[position]]
    }

    @discardableResult
    public mutating func start() -> Track? {
        guard !order.isEmpty else { return nil }
        position = 0
        return currentTrack
    }

    @discardableResult
    public mutating func advance() -> Track? {
        guard let currentPosition = position else { return start() }
        if repeatMode == .one {
            return currentTrack
        }
        let nextPosition = currentPosition + 1
        if nextPosition < order.count {
            position = nextPosition
            return currentTrack
        }
        guard repeatMode == .all, !order.isEmpty else {
            position = nil
            return nil
        }
        position = 0
        return currentTrack
    }

    @discardableResult
    public mutating func retreat() -> Track? {
        guard let currentPosition = position else { return nil }
        let previousPosition = currentPosition - 1
        if previousPosition >= 0 {
            position = previousPosition
            return currentTrack
        }
        guard repeatMode == .all, !order.isEmpty else { return nil }
        position = order.count - 1
        return currentTrack
    }

    public func peekNext() -> Track? {
        guard let currentPosition = position else { return order.first.map { tracks[$0] } }
        if repeatMode == .one {
            return currentTrack
        }
        let nextPosition = currentPosition + 1
        if nextPosition < order.count {
            return tracks[order[nextPosition]]
        }
        guard repeatMode == .all, !order.isEmpty else { return nil }
        return tracks[order[0]]
    }

    public mutating func setTracks(_ newTracks: [Track]) {
        tracks = newTracks
        order = Array(tracks.indices)
        if shuffle {
            order.shuffle()
        }
        position = nil
    }

    private mutating func rebuildOrder() {
        let currentTrackIndex = position.map { order[$0] }
        order = Array(tracks.indices)
        if shuffle {
            order.shuffle()
        }
        position = currentTrackIndex.flatMap { order.firstIndex(of: $0) }
    }
}
