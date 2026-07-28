import CoreAudio

public enum CoreAudioError: Error, Equatable {
    case osStatus(OSStatus)
}

func checkStatus(_ status: OSStatus) throws {
    guard status == noErr else {
        throw CoreAudioError.osStatus(status)
    }
}

func propertyAddress(
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
}

func propertyDataSize(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) throws -> UInt32 {
    var address = address
    var size: UInt32 = 0
    try checkStatus(AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size))
    return size
}

func hasProperty(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
    var address = address
    return AudioObjectHasProperty(objectID, &address)
}

func getObjectIDArray(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) throws -> [AudioObjectID] {
    var address = address
    let size = try propertyDataSize(objectID, address)
    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    guard count > 0 else { return [] }
    var result = [AudioObjectID](repeating: 0, count: count)
    var actualSize = size
    try result.withUnsafeMutableBytes { buffer in
        try checkStatus(AudioObjectGetPropertyData(objectID, &address, 0, nil, &actualSize, buffer.baseAddress!))
    }
    return result
}

func getValueRangeArray(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) throws -> [AudioValueRange] {
    var address = address
    let size = try propertyDataSize(objectID, address)
    let count = Int(size) / MemoryLayout<AudioValueRange>.size
    guard count > 0 else { return [] }
    var result = [AudioValueRange](repeating: AudioValueRange(mMinimum: 0, mMaximum: 0), count: count)
    var actualSize = size
    try result.withUnsafeMutableBytes { buffer in
        try checkStatus(AudioObjectGetPropertyData(objectID, &address, 0, nil, &actualSize, buffer.baseAddress!))
    }
    return result
}

func getFloat64(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) throws -> Float64 {
    var address = address
    var value: Float64 = 0
    var size = UInt32(MemoryLayout<Float64>.size)
    try checkStatus(AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value))
    return value
}

func setFloat64(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress, _ value: Float64) throws {
    var address = address
    var value = value
    let size = UInt32(MemoryLayout<Float64>.size)
    try checkStatus(AudioObjectSetPropertyData(objectID, &address, 0, nil, size, &value))
}

func getFloat32(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) throws -> Float32 {
    var address = address
    var value: Float32 = 0
    var size = UInt32(MemoryLayout<Float32>.size)
    try checkStatus(AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value))
    return value
}

func setFloat32(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress, _ value: Float32) throws {
    var address = address
    var value = value
    let size = UInt32(MemoryLayout<Float32>.size)
    try checkStatus(AudioObjectSetPropertyData(objectID, &address, 0, nil, size, &value))
}

func getUInt32(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) throws -> UInt32 {
    var address = address
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    try checkStatus(AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value))
    return value
}

func getString(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) throws -> String {
    var address = address
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    try checkStatus(AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value))
    guard let value else { return "" }
    return value.takeRetainedValue() as String
}

func isPropertySettable(_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
    var address = address
    var settable: DarwinBoolean = false
    let status = AudioObjectIsPropertySettable(objectID, &address, &settable)
    return status == noErr && settable.boolValue
}
