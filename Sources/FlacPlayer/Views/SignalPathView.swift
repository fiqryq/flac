import FlacPlayerCore
import SwiftUI

struct SignalPathView: View {
    @Environment(PlayerModel.self) private var playerModel

    var body: some View {
        if let track = playerModel.currentTrack {
            ScrollView {
                content(for: track)
                    .padding(24)
            }
            .navigationTitle("")
        } else {
            ContentUnavailableView("Not Playing", systemImage: "waveform")
        }
    }

    @ViewBuilder
    private func content(for track: Track) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                ArtworkThumbnail(image: playerModel.currentArtwork, size: 64, cornerRadius: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.title3.bold())
                    Text(track.artist)
                        .foregroundStyle(.secondary)
                }
            }

            statusBanner

            WaveformMeterView(levels: playerModel.recentLevels)
                .frame(height: 80)

            VStack(alignment: .leading, spacing: 14) {
                field("Format", track.formatDescription)
                field("Channels", track.channelDescription)
                field("Output Device", playerModel.selectedDevice?.name ?? "—")
                field("App Volume", String(format: "%.0f%%", playerModel.volume * 100))
                field("Equalizer", playerModel.eqEnabled ? "On (\(playerModel.currentPresetName))" : "Off")
            }
        }
    }

    private var statusBanner: some View {
        let status = playerModel.signalPathStatus
        return HStack(spacing: 10) {
            Circle()
                .fill(status.isBitPerfect ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(status.description)
                .font(.callout)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

private struct WaveformMeterView: View {
    let levels: [Float]

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            guard levels.count > 1 else {
                var flat = Path()
                flat.move(to: CGPoint(x: 0, y: midY))
                flat.addLine(to: CGPoint(x: size.width, y: midY))
                context.stroke(flat, with: .color(.primary.opacity(0.12)), lineWidth: 1)
                return
            }

            let stepX = size.width / CGFloat(levels.count - 1)
            var envelope = Path()
            for (index, level) in levels.enumerated() {
                let x = CGFloat(index) * stepX
                let amplitude = CGFloat(min(max(level, 0), 1)) * midY
                let point = CGPoint(x: x, y: midY - amplitude)
                if index == 0 { envelope.move(to: point) } else { envelope.addLine(to: point) }
            }
            for (index, level) in levels.enumerated().reversed() {
                let x = CGFloat(index) * stepX
                let amplitude = CGFloat(min(max(level, 0), 1)) * midY
                envelope.addLine(to: CGPoint(x: x, y: midY + amplitude))
            }
            envelope.closeSubpath()

            context.fill(
                envelope,
                with: .linearGradient(
                    Gradient(colors: [Color.flacAccent.opacity(0.55), Color.flacAccent.opacity(0.12)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: midY))
            baseline.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(baseline, with: .color(.primary.opacity(0.12)), lineWidth: 1)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .animation(.linear(duration: 0.05), value: levels)
    }
}
