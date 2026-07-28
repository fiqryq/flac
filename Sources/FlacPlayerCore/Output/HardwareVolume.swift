import CoreAudio

public enum HardwareVolumeError: Error, Equatable {
    case unsupportedByDevice
}

public enum HardwareVolume {
    public static func isSupported(for deviceID: AudioObjectID) -> Bool {
        let address = propertyAddress(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput)
        return hasProperty(deviceID, address) && isPropertySettable(deviceID, address)
    }

    public static func currentVolume(for deviceID: AudioObjectID) throws -> Float32 {
        try getFloat32(deviceID, propertyAddress(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput))
    }

    public static func setVolume(_ volume: Float32, for deviceID: AudioObjectID) throws {
        guard isSupported(for: deviceID) else { throw HardwareVolumeError.unsupportedByDevice }
        let clamped = min(max(volume, 0), 1)
        try setFloat32(deviceID, propertyAddress(kAudioDevicePropertyVolumeScalar, scope: kAudioObjectPropertyScopeOutput), clamped)
    }
}
