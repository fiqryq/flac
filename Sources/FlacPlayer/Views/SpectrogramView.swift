import FlacPlayerCore
import SwiftUI

struct SpectrogramView: View {
    @Environment(PlayerModel.self) private var playerModel
    @State private var spectrogram: Spectrogram?
    @State private var image: NSImage?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var analyzedFilePath: String?

    var body: some View {
        if let track = playerModel.currentTrack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(for: track)
                    content(for: track)
                }
                .padding(24)
            }
            .navigationTitle("")
        } else {
            ContentUnavailableView("Not Playing", systemImage: "waveform.path.ecg")
        }
    }

    @ViewBuilder
    private func header(for track: Track) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.title)
                .font(.title3.bold())
            Text(track.artist)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func content(for track: Track) -> some View {
        if isAnalyzing {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Analyzing full-file frequency content…")
                    .foregroundStyle(.secondary)
            }
        } else if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(.orange)
            analyzeButton(for: track, label: "Retry")
        } else if let spectrogram, let image, analyzedFilePath == track.filePath {
            spectrogramCanvas(image: image)
            cutoffSummary(spectrogram, track: track)
            analyzeButton(for: track, label: "Re-analyze")
        } else {
            Text("Runs a full-file FFT to show the actual frequency content of this track — the fastest way to tell a genuine hi-res master from a lossy source that was upsampled and repackaged as one.")
                .font(.callout)
                .foregroundStyle(.secondary)
            analyzeButton(for: track, label: "Analyze")
        }
    }

    @ViewBuilder
    private func spectrogramCanvas(image: NSImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack {
                Text("0 Hz")
                Spacer()
                if let spectrogram {
                    Text("\(Int(spectrogram.nyquistHz / 1000)) kHz")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func cutoffSummary(_ spectrogram: Spectrogram, track: Track) -> some View {
        if let cutoff = spectrogram.detectedCutoffHz {
            let nyquist = spectrogram.nyquistHz
            let suspicious = cutoff < nyquist * 0.85 && cutoff < 19000
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: suspicious ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .foregroundStyle(suspicious ? .orange : .green)
                Text(suspicious
                    ? "Content rolls off around \(Int(cutoff))Hz — well short of this file's \(Int(nyquist))Hz ceiling. Possibly upsampled from a narrower-band source."
                    : "Content extends to about \(Int(cutoff))Hz, consistent with genuine \(track.formatDescription) material."
                )
                .font(.callout)
            }
        }
    }

    private func analyzeButton(for track: Track, label: String) -> some View {
        Button(label) { analyze(track) }
            .buttonStyle(.bordered)
    }

    private func analyze(_ track: Track) {
        isAnalyzing = true
        errorMessage = nil
        let path = track.filePath
        let codec = track.codec
        Task.detached(priority: .utility) {
            do {
                let result = try SpectrogramAnalyzer.analyze(forCodec: codec, url: URL(fileURLWithPath: path))
                let rendered = Self.makeImage(from: result)
                await MainActor.run {
                    spectrogram = result
                    image = rendered
                    analyzedFilePath = path
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Couldn't analyze file: \(error)"
                    isAnalyzing = false
                }
            }
        }
    }

    private nonisolated static func makeImage(from spectrogram: Spectrogram) -> NSImage? {
        guard !spectrogram.columns.isEmpty, let rows = spectrogram.columns.first?.count, rows > 0 else { return nil }
        let width = spectrogram.columns.count
        let height = rows
        guard let maxDB = spectrogram.columns.lazy.flatMap({ $0 }).max() else { return nil }
        let minDB = maxDB - 80

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for x in 0..<width {
            let column = spectrogram.columns[x]
            for y in 0..<height {
                let value = column[y]
                let t = (value - minDB) / (maxDB - minDB)
                let clamped = min(max(t, 0), 1)
                let (r, g, b) = colorRamp(clamped)
                let flippedY = height - 1 - y
                let index = (flippedY * width + x) * 4
                pixels[index] = r
                pixels[index + 1] = g
                pixels[index + 2] = b
                pixels[index + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        guard let cgImage = CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ) else { return nil }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    private nonisolated static func colorRamp(_ t: Float) -> (UInt8, UInt8, UInt8) {
        let stops: [(Float, Float, Float, Float)] = [
            (0.0, 0.04, 0.02, 0.07),
            (0.4, 0.35, 0.08, 0.20),
            (0.7, 0.85, 0.20, 0.30),
            (1.0, 1.0, 0.85, 0.55),
        ]
        for i in 0..<(stops.count - 1) {
            let (t0, r0, g0, b0) = stops[i]
            let (t1, r1, g1, b1) = stops[i + 1]
            if t >= t0 && t <= t1 {
                let f = t1 > t0 ? (t - t0) / (t1 - t0) : 0
                return (
                    UInt8(min(max((r0 + (r1 - r0) * f) * 255, 0), 255)),
                    UInt8(min(max((g0 + (g1 - g0) * f) * 255, 0), 255)),
                    UInt8(min(max((b0 + (b1 - b0) * f) * 255, 0), 255))
                )
            }
        }
        return (255, 255, 255)
    }
}
