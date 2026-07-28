import FlacPlayerCore
import SwiftUI

struct EqualizerView: View {
    @Environment(PlayerModel.self) private var playerModel

    var body: some View {
        @Bindable var playerModel = playerModel

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                EqualizerGraph(bands: $playerModel.eqBands)
                    .frame(height: 300)

                HStack {
                    Spacer()
                    Button("Reset") {
                        playerModel.resetEQ()
                    }
                    .buttonStyle(.bordered)
                }

                statusCaption
            }
            .padding(24)
        }
        .navigationTitle("")
    }

    private var header: some View {
        @Bindable var playerModel = playerModel
        return HStack(spacing: 8) {
            Text("Presets")
                .foregroundStyle(.secondary)

            Picker("Presets", selection: presetSelection) {
                ForEach(presetNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            Spacer()

            Toggle("On", isOn: $playerModel.eqEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private var presetNames: [String] {
        var names = EQPreset.all.map(\.name)
        if playerModel.currentPresetName == "Custom" {
            names.append("Custom")
        }
        return names
    }

    private var presetSelection: Binding<String> {
        Binding(
            get: { playerModel.currentPresetName },
            set: { name in
                guard let preset = EQPreset.all.first(where: { $0.name == name }) else { return }
                playerModel.applyPreset(preset)
            }
        )
    }

    private var statusCaption: some View {
        Group {
            if !playerModel.eqEnabled {
                Text("EQ is off — bit-perfect output is preserved until you turn it on.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if playerModel.currentPresetName == "Flat" {
                Text("Flat — bit-perfect output is preserved.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Any non-flat band means output is no longer bit-perfect.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct EqualizerGraph: View {
    @Binding var bands: [EQBand]

    private let minDB: Double = -12
    private let maxDB: Double = 12
    private let leadingInset: CGFloat = 40
    private let topInset: CGFloat = 14
    private let bottomInset: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let plotWidth = max(geo.size.width - leadingInset, 0)
            let plotHeight = max(geo.size.height - topInset - bottomInset, 0)
            let points = curvePoints(plotWidth: plotWidth, plotHeight: plotHeight)
            let baselineY = yPosition(forGain: 0, plotHeight: plotHeight)

            ZStack(alignment: .topLeading) {
                Text("+\(Int(maxDB))dB")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .position(x: leadingInset / 2, y: topInset + 6)
                Text("\(Int(minDB))dB")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .position(x: leadingInset / 2, y: topInset + plotHeight - 6)

                ForEach(points.indices, id: \.self) { index in
                    Path { path in
                        path.move(to: CGPoint(x: points[index].x, y: topInset))
                        path.addLine(to: CGPoint(x: points[index].x, y: topInset + plotHeight))
                    }
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)

                    Text(frequencyLabel(for: bands[index].frequency))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .position(x: points[index].x, y: topInset + plotHeight + 12)
                }

                Path { path in
                    path.move(to: CGPoint(x: leadingInset, y: baselineY))
                    path.addLine(to: CGPoint(x: leadingInset + plotWidth, y: baselineY))
                }
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)

                areaPath(points: points, baselineY: baselineY)
                    .fill(
                        LinearGradient(
                            colors: [Color.flacAccent.opacity(0.5), Color.flacAccent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                curvePath(points: points)
                    .stroke(Color.flacAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                ForEach(points.indices, id: \.self) { index in
                    dragColumn(index: index, x: points[index].x, plotHeight: plotHeight)
                    handle(at: points[index])
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func dragColumn(index: Int, x: CGFloat, plotHeight: CGFloat) -> some View {
        Color.clear
            .frame(width: 28, height: plotHeight)
            .contentShape(Rectangle())
            .position(x: x, y: topInset + plotHeight / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedY = min(max(value.location.y, 0), plotHeight)
                        let fraction = 1 - clampedY / plotHeight
                        let newGain = minDB + fraction * (maxDB - minDB)
                        bands[index].gainDB = min(max(newGain, minDB), maxDB)
                    }
            )
    }

    private func handle(at point: CGPoint) -> some View {
        Circle()
            .fill(.white)
            .overlay(Circle().strokeBorder(Color.flacAccent, lineWidth: 1.5))
            .frame(width: 12, height: 12)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .position(point)
            .allowsHitTesting(false)
    }

    private func curvePoints(plotWidth: CGFloat, plotHeight: CGFloat) -> [CGPoint] {
        let count = bands.count
        return bands.enumerated().map { index, band in
            let x = leadingInset + (count > 1 ? plotWidth * CGFloat(index) / CGFloat(count - 1) : plotWidth / 2)
            return CGPoint(x: x, y: yPosition(forGain: band.gainDB, plotHeight: plotHeight))
        }
    }

    private func yPosition(forGain gain: Double, plotHeight: CGFloat) -> CGFloat {
        let fraction = (gain - minDB) / (maxDB - minDB)
        return topInset + plotHeight * CGFloat(1 - fraction)
    }

    private func curvePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        appendCatmullRom(to: &path, points: points)
        return path
    }

    private func areaPath(points: [CGPoint], baselineY: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }
        path.move(to: CGPoint(x: first.x, y: baselineY))
        path.addLine(to: first)
        appendCatmullRom(to: &path, points: points)
        path.addLine(to: CGPoint(x: last.x, y: baselineY))
        path.closeSubpath()
        return path
    }

    private func appendCatmullRom(to path: inout Path, points: [CGPoint]) {
        guard points.count > 1 else { return }
        let extended = [points.first!] + points + [points.last!]
        for i in 1..<(extended.count - 2) {
            let p0 = extended[i - 1], p1 = extended[i], p2 = extended[i + 1], p3 = extended[i + 2]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
    }

    private func frequencyLabel(for frequency: Double) -> String {
        guard frequency >= 1000 else { return "\(Int(frequency))Hz" }
        let khz = frequency / 1000
        return khz == khz.rounded() ? "\(Int(khz))KHz" : String(format: "%.1fKHz", khz)
    }
}
