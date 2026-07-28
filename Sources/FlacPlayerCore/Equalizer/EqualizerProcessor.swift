import Darwin

final class EqualizerProcessor {
    struct Snapshot {
        let coefficients: [BiquadCoefficients]
        let enabled: Bool
    }

    private var lock = os_unfair_lock()
    private var coefficients: [BiquadCoefficients] = []
    private var enabled = false
    private var pendingBandCountChange = false
    private var pendingChannelCount: Int?

    private var state: [[BiquadState]] = []
    private var channelCount = 2


    func updateBands(_ bands: [EQBand], sampleRate: Double) {
        let newCoefficients = bands.map {
            BiquadCoefficients.peaking(frequency: $0.frequency, gainDB: $0.gainDB, q: $0.q, sampleRate: sampleRate)
        }
        os_unfair_lock_lock(&lock)
        if newCoefficients.count != coefficients.count {
            pendingBandCountChange = true
        }
        coefficients = newCoefficients
        os_unfair_lock_unlock(&lock)
    }

    func setEnabled(_ enabled: Bool) {
        os_unfair_lock_lock(&lock)
        self.enabled = enabled
        os_unfair_lock_unlock(&lock)
    }

    func setChannelCount(_ count: Int) {
        os_unfair_lock_lock(&lock)
        pendingChannelCount = count
        os_unfair_lock_unlock(&lock)
    }


    func prepareForRenderPass() -> Snapshot {
        os_unfair_lock_lock(&lock)
        let snapshotCoefficients = coefficients
        let snapshotEnabled = enabled
        let needsRebuild = pendingBandCountChange || pendingChannelCount != nil
        let newChannelCount = pendingChannelCount
        pendingBandCountChange = false
        pendingChannelCount = nil
        os_unfair_lock_unlock(&lock)

        if let newChannelCount {
            channelCount = newChannelCount
        }
        if needsRebuild {
            state = (0..<channelCount).map { _ in (0..<snapshotCoefficients.count).map { _ in BiquadState() } }
        }
        return Snapshot(coefficients: snapshotCoefficients, enabled: snapshotEnabled)
    }

    func process(_ sample: Float, channel: Int, snapshot: Snapshot) -> Float {
        guard snapshot.enabled, channel < state.count else { return sample }
        var output = sample
        let bandStates = state[channel]
        for index in 0..<min(snapshot.coefficients.count, bandStates.count) {
            output = bandStates[index].process(output, snapshot.coefficients[index])
        }
        return output
    }
}
