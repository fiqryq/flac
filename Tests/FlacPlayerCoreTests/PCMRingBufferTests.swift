import Testing
@testable import FlacPlayerCore

private func makeBuffer(channelCount: Int, values: [Int32]) -> PCMBuffer {
    let buffer = PCMBuffer(channelCount: channelCount, capacity: values.count)
    for channel in 0..<channelCount {
        for i in 0..<values.count {
            buffer.channelData[channel][i] = values[i]
        }
    }
    buffer.setFrameCount(values.count)
    return buffer
}

@Test func writeThenReadRoundTrips() {
    let ring = PCMRingBuffer(channelCount: 2, capacity: 16)
    let input = makeBuffer(channelCount: 2, values: Array(0..<8).map(Int32.init))
    #expect(ring.write(from: input) == 8)

    let output = PCMBuffer(channelCount: 2, capacity: 16)
    let read = ring.read(into: output)
    #expect(read == 8)
    for i in 0..<8 {
        #expect(output.channelData[0][i] == Int32(i))
        #expect(output.channelData[1][i] == Int32(i))
    }
}

@Test func writeStopsAtCapacity() {
    let ring = PCMRingBuffer(channelCount: 1, capacity: 4)
    let input = makeBuffer(channelCount: 1, values: [1, 2, 3, 4, 5, 6])
    #expect(ring.write(from: input) == 4)
    #expect(ring.availableToWrite == 0)
}

@Test func readReturnsZeroWhenEmpty() {
    let ring = PCMRingBuffer(channelCount: 2, capacity: 8)
    let output = PCMBuffer(channelCount: 2, capacity: 8)
    #expect(ring.read(into: output) == 0)
}

@Test func wrapsAroundCorrectlyAcrossMultipleWritesAndReads() {
    let ring = PCMRingBuffer(channelCount: 1, capacity: 4)

    let first = makeBuffer(channelCount: 1, values: [1, 2, 3])
    #expect(ring.write(from: first) == 3)

    let out1 = PCMBuffer(channelCount: 1, capacity: 2)
    #expect(ring.read(into: out1) == 2)
    #expect(out1.channelData[0][0] == 1)
    #expect(out1.channelData[0][1] == 2)

    let second = makeBuffer(channelCount: 1, values: [4, 5, 6])
    #expect(ring.write(from: second) == 3)

    let out2 = PCMBuffer(channelCount: 1, capacity: 4)
    let read = ring.read(into: out2)
    #expect(read == 4)
    #expect(out2.channelData[0][0] == 3)
    #expect(out2.channelData[0][1] == 4)
    #expect(out2.channelData[0][2] == 5)
    #expect(out2.channelData[0][3] == 6)
}
