import CoreAudio

public struct OutputDevice: Identifiable, Equatable, Hashable, Sendable {
    public let id: AudioObjectID
    public let name: String

    public init(id: AudioObjectID, name: String) {
        self.id = id
        self.name = name
    }
}

public enum OutputDeviceCatalog {
    public static func listOutputDevices() throws -> [OutputDevice] {
        let deviceIDs = try getObjectIDArray(
            AudioObjectID(kAudioObjectSystemObject),
            propertyAddress(kAudioHardwarePropertyDevices)
        )
        return try deviceIDs.compactMap { id in
            guard try streamConfigurationHasOutputChannels(id) else { return nil }
            let name = try getString(id, propertyAddress(kAudioObjectPropertyName))
            return OutputDevice(id: id, name: name)
        }
    }

    public static func defaultOutputDevice() throws -> OutputDevice? {
        let id = try getUInt32(
            AudioObjectID(kAudioObjectSystemObject),
            propertyAddress(kAudioHardwarePropertyDefaultOutputDevice)
        )
        guard id != 0, try streamConfigurationHasOutputChannels(id) else { return nil }
        let name = try getString(id, propertyAddress(kAudioObjectPropertyName))
        return OutputDevice(id: id, name: name)
    }

    private static func streamConfigurationHasOutputChannels(_ deviceID: AudioObjectID) throws -> Bool {
        let address = propertyAddress(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeOutput)
        guard hasProperty(deviceID, address) else { return false }
        let size = try propertyDataSize(deviceID, address)
        guard size > 0 else { return false }

        var data = [UInt8](repeating: 0, count: Int(size))
        var actualSize = size
        var addr = address
        try data.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            try checkStatus(AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &actualSize, base))
        }
        return data.withUnsafeBytes { buffer -> Bool in
            let bufferList = buffer.bindMemory(to: AudioBufferList.self).baseAddress!
            let audioBufferList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))
            return audioBufferList.contains { $0.mNumberChannels > 0 }
        }
    }
}
