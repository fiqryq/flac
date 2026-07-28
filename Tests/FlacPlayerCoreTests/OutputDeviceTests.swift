import Testing
@testable import FlacPlayerCore

@Test func listsAtLeastOneOutputDevice() throws {
    let devices = try OutputDeviceCatalog.listOutputDevices()
    #expect(!devices.isEmpty)
    for device in devices {
        #expect(!device.name.isEmpty)
    }
}

@Test func defaultOutputDeviceIsAmongListedDevices() throws {
    let devices = try OutputDeviceCatalog.listOutputDevices()
    guard let defaultDevice = try OutputDeviceCatalog.defaultOutputDevice() else {
        Issue.record("expected a default output device on this machine")
        return
    }
    #expect(devices.contains(defaultDevice))
}

@Test func defaultDeviceReportsAtLeastOneSampleRate() throws {
    guard let defaultDevice = try OutputDeviceCatalog.defaultOutputDevice() else {
        Issue.record("expected a default output device on this machine")
        return
    }
    let rates = try SampleRateSupport.availableSampleRates(for: defaultDevice.id)
    #expect(!rates.isEmpty)

    let current = try SampleRateSupport.currentNominalSampleRate(for: defaultDevice.id)
    #expect(current > 0)
    #expect(try SampleRateSupport.supports(sampleRate: current, deviceID: defaultDevice.id))
}
