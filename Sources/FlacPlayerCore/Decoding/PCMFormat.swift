public struct PCMFormat: Equatable, Sendable {
    public let sampleRate: Double
    public let bitDepth: Int
    public let channelCount: Int

    public init(sampleRate: Double, bitDepth: Int, channelCount: Int) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channelCount = channelCount
    }
}
