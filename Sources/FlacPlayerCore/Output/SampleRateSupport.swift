import CoreAudio

public enum SampleRateSupport {
    public static func availableSampleRates(for deviceID: AudioObjectID) throws -> [ClosedRange<Double>] {
        let ranges = try getValueRangeArray(deviceID, propertyAddress(kAudioDevicePropertyAvailableNominalSampleRates))
        return ranges.compactMap { range in
            guard range.mMinimum <= range.mMaximum else { return nil }
            return range.mMinimum...range.mMaximum
        }
    }

    public static func supports(sampleRate: Double, deviceID: AudioObjectID) throws -> Bool {
        try availableSampleRates(for: deviceID).contains { $0.contains(sampleRate) }
    }

    public static func currentNominalSampleRate(for deviceID: AudioObjectID) throws -> Double {
        try getFloat64(deviceID, propertyAddress(kAudioDevicePropertyNominalSampleRate))
    }

    public static func setNominalSampleRate(_ rate: Double, for deviceID: AudioObjectID) throws {
        try setFloat64(deviceID, propertyAddress(kAudioDevicePropertyNominalSampleRate), rate)
    }
}
