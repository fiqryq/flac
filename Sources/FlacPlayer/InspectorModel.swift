import FlacPlayerCore
import Observation

@Observable
@MainActor
final class InspectorModel {
    var track: Track? {
        didSet { if let track { lastTrack = track } }
    }

    private(set) var lastTrack: Track?

    func toggle(fallback: Track?) {
        track = track == nil ? (lastTrack ?? fallback) : nil
    }
}
