import FlacPlayerCore
import SwiftUI

struct NowPlayingBar: View {
    @Environment(PlayerModel.self) private var playerModel
    @Environment(InspectorModel.self) private var inspectorModel
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0
    @State private var isLCDHovered = false

    private let lcdHeight: CGFloat = 46
    private let artworkSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 16) {
            transportCluster
            Spacer(minLength: 8)
            lcd
            Spacer(minLength: 8)
            ViewThatFits(in: .horizontal) {
                trailingControls(showVolume: true)
                trailingControls(showVolume: false)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .glassSurface(Capsule(), interactive: true)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var transportCluster: some View {
        @Bindable var playerModel = playerModel
        return HStack(spacing: 20) {
            Toggle(isOn: $playerModel.shuffle) {
                Image(systemName: "shuffle")
                    .font(.system(size: 12, weight: .semibold))
            }
            .toggleStyle(.button)
            .foregroundStyle(playerModel.shuffle ? Color.flacAccent : Color.secondary)
            .help("Shuffle")

            Button(action: playerModel.previous) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 15))
            }
            .help("Previous")

            Button(action: playerModel.togglePlayPause) {
                Image(systemName: playerModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 26)
            }
            .help(playerModel.isPlaying ? "Pause" : "Play")

            Button(action: playerModel.next) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 15))
            }
            .help("Next")

            Button(action: playerModel.cycleRepeatMode) {
                Image(systemName: repeatIcon)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(playerModel.repeatMode == .off ? Color.secondary : Color.flacAccent)
            .help("Repeat")
        }
        .buttonStyle(.plain)
    }

    private var lcd: some View {
        ZStack {
            if playerModel.currentTrack != nil {
                lcdContent
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 17))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: lcdHeight)
        .frame(maxWidth: 440)
        .onHover { isLCDHovered = $0 }
    }

    private var lcdContent: some View {
        Button {
            inspectorModel.track = playerModel.currentTrack
        } label: {
            HStack(spacing: 10) {
                ArtworkThumbnail(image: playerModel.currentArtwork, size: artworkSize, cornerRadius: 5)
                Spacer(minLength: 0)
                VStack(spacing: 1) {
                    Text(playerModel.currentTrack?.title ?? "")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(playerModel.currentTrack?.artist ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Color.clear.frame(width: artworkSize)
            }
        }
        .buttonStyle(.plain)
        .help("Show track details")
        .overlay(alignment: .bottom) {
            LCDScrubber(
                fraction: playerModel.duration > 0 ? displayedTime / playerModel.duration : 0,
                onScrub: { fraction in
                    isScrubbing = true
                    scrubTime = fraction * playerModel.duration
                },
                onCommit: {
                    playerModel.seek(to: scrubTime)
                    isScrubbing = false
                }
            )
            .padding(.leading, artworkSize + 10)
        }
        .overlay(alignment: .bottomLeading) {
            if showsTimes {
                timeLabel(formattedTime(displayedTime))
                    .padding(.leading, artworkSize + 10)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsTimes {
                timeLabel("-" + formattedTime(max(playerModel.duration - displayedTime, 0)))
            }
        }
    }

    private var showsTimes: Bool {
        isLCDHovered || isScrubbing
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
            .allowsHitTesting(false)
    }

    private func trailingControls(showVolume: Bool) -> some View {
        HStack(spacing: 14) {
            signalPathIndicator
            if showVolume {
                volumeControl
            }
            deviceMenu
        }
        .buttonStyle(.plain)
        .font(.body)
    }

    private var signalPathIndicator: some View {
        let status = playerModel.signalPathStatus
        return Circle()
            .fill(status.isBitPerfect ? Color.green : Color.orange)
            .frame(width: 7, height: 7)
            .help(status.description)
    }

    private var volumeControl: some View {
        @Bindable var playerModel = playerModel
        return HStack(spacing: 6) {
            Image(systemName: "speaker.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Slider(value: $playerModel.volume, in: 0...1)
                .controlSize(.small)
                .frame(width: 84)
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var deviceMenu: some View {
        Menu {
            ForEach(playerModel.availableDevices) { device in
                Button {
                    playerModel.selectedDevice = device
                } label: {
                    if device == playerModel.selectedDevice {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            Image(systemName: "hifispeaker.fill")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(playerModel.selectedDevice?.name ?? "Output device")
    }

    private var repeatIcon: String {
        playerModel.repeatMode == .one ? "repeat.1" : "repeat"
    }

    private var displayedTime: Double {
        isScrubbing ? scrubTime : playerModel.currentTime
    }

    private func formattedTime(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct LCDScrubber: View {
    let fraction: Double
    let onScrub: (Double) -> Void
    let onCommit: () -> Void

    @State private var isHovering = false
    @State private var isDragging = false

    private var isActive: Bool { isHovering || isDragging }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clamped = min(max(fraction, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(isActive ? Color.flacAccent : Color.primary.opacity(0.3))
                    .frame(width: max(3, clamped * width))
            }
            .frame(height: isActive ? 5 : 3)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        onScrub(min(max(value.location.x / width, 0), 1))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onCommit()
                    }
            )
        }
        .frame(height: 12)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isActive)
    }
}
