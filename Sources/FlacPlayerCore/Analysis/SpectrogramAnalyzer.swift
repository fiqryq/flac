import Accelerate
import Foundation

public struct Spectrogram: Sendable {
    public let columns: [[Float]]
    public let sampleRate: Double
    public var nyquistHz: Double { sampleRate / 2 }
    public let detectedCutoffHz: Double?
}

public enum SpectrogramAnalyzerError: Error {
    case unsupportedCodec(String)
    case fftSetupFailed
}

public enum SpectrogramAnalyzer {
    private static let fftSize = 4096
    private static let hopSize = fftSize / 2
    private static let maxColumns = 300
    private static let maxRows = 256
    private static let cutoffThresholdDB: Float = -60

    public static func analyze(forCodec codec: String, url: URL) throws -> Spectrogram {
        try analyze(decoder: try makeDecoder(forCodec: codec, url: url))
    }

    public static func analyze(decoder: AudioDecoder) throws -> Spectrogram {
        let format = decoder.format
        let samples = try readAllSamplesMono(decoder: decoder)

        guard samples.count >= fftSize,
              let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
        else {
            return Spectrogram(columns: [], sampleRate: format.sampleRate, detectedCutoffHz: nil)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let log2n = vDSP_Length(log2(Float(fftSize)))
        let halfSize = fftSize / 2

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var rawColumns: [[Float]] = []
        var offset = 0

        while offset + fftSize <= samples.count {
            var windowed = [Float](repeating: 0, count: fftSize)
            samples.withUnsafeBufferPointer { samplesPtr in
                vDSP_vmul(samplesPtr.baseAddress! + offset, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))
            }

            var realp = [Float](repeating: 0, count: halfSize)
            var imagp = [Float](repeating: 0, count: halfSize)
            var magnitudes = [Float](repeating: 0, count: halfSize)

            realp.withUnsafeMutableBufferPointer { realPtr in
                imagp.withUnsafeMutableBufferPointer { imagPtr in
                    var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    windowed.withUnsafeBufferPointer { windowedPtr in
                        windowedPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                            vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfSize))
                        }
                    }
                    vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfSize))
                }
            }

            var db = [Float](repeating: 0, count: halfSize)
            let floor: Float = 1e-9
            for i in 0..<halfSize {
                db[i] = 10 * log10f(max(magnitudes[i], floor))
            }
            rawColumns.append(db)
            offset += hopSize
        }

        let cutoff = detectCutoff(rawColumns: rawColumns, sampleRate: format.sampleRate, halfSize: halfSize)
        let columns = downsample(rawColumns, maxColumns: maxColumns, maxRows: maxRows)
        return Spectrogram(columns: columns, sampleRate: format.sampleRate, detectedCutoffHz: cutoff)
    }

    private static func detectCutoff(rawColumns: [[Float]], sampleRate: Double, halfSize: Int) -> Double? {
        guard !rawColumns.isEmpty else { return nil }
        var averaged = [Float](repeating: 0, count: halfSize)
        for column in rawColumns {
            for i in 0..<halfSize { averaged[i] += column[i] }
        }
        let count = Float(rawColumns.count)
        for i in 0..<halfSize { averaged[i] /= count }

        guard let peak = averaged.max() else { return nil }
        let threshold = peak + cutoffThresholdDB

        var lastAboveThreshold = 0
        for i in 0..<halfSize where averaged[i] >= threshold {
            lastAboveThreshold = i
        }
        let binHz = sampleRate / 2 / Double(halfSize)
        return Double(lastAboveThreshold) * binHz
    }

    private static func downsample(_ rawColumns: [[Float]], maxColumns: Int, maxRows: Int) -> [[Float]] {
        guard !rawColumns.isEmpty else { return [] }
        let halfSize = rawColumns[0].count
        let columnGroups = groupIndices(count: rawColumns.count, into: maxColumns)
        let rowGroups = groupIndices(count: halfSize, into: maxRows)

        return columnGroups.map { columnRange in
            rowGroups.map { rowRange in
                var total: Float = 0
                var n = 0
                for c in columnRange {
                    for r in rowRange {
                        total += rawColumns[c][r]
                        n += 1
                    }
                }
                return n > 0 ? total / Float(n) : -160
            }
        }
    }

    private static func groupIndices(count: Int, into groups: Int) -> [Range<Int>] {
        guard count > 0 else { return [] }
        let groups = min(groups, count)
        return (0..<groups).map { g in
            let start = count * g / groups
            let end = max(count * (g + 1) / groups, start + 1)
            return start..<end
        }
    }

    private static func readAllSamplesMono(decoder: AudioDecoder) throws -> [Float] {
        let format = decoder.format
        let scale = Float(1 << (format.bitDepth - 1))
        let chunkFrames = 65536
        let buffer = PCMBuffer(channelCount: format.channelCount, capacity: chunkFrames)
        var mono: [Float] = []
        if let total = decoder.totalFrames {
            mono.reserveCapacity(Int(total))
        }

        while true {
            let framesRead = try decoder.readFrames(into: buffer)
            if framesRead == 0 { break }
            for frame in 0..<framesRead {
                var sum: Float = 0
                for channel in 0..<format.channelCount {
                    sum += Float(buffer.channelData[channel][frame])
                }
                mono.append(sum / Float(format.channelCount) / scale)
            }
        }
        return mono
    }

    private static func makeDecoder(forCodec codec: String, url: URL) throws -> AudioDecoder {
        switch codec {
        case "FLAC":
            return try FLACDecoder(url: url)
        case "ALAC", "PCM":
            return try ExtAudioFileDecoder(url: url)
        default:
            throw SpectrogramAnalyzerError.unsupportedCodec(codec)
        }
    }
}
