import SwiftUI

extension Color {
    static let flacAccent = Color(red: 0.98, green: 0.20, blue: 0.35)
}

struct SidebarIconBadge: View {
    let systemName: String
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color.gradient)
            .frame(width: 22, height: 22)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

struct ContentHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
            Divider()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

@available(macOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {
    @ViewBuilder
    func glassSurface(_ shape: some InsettableShape, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self
                .background {
                    ZStack {
                        VisualEffectView(material: .sidebar)
                        if let tint { tint.opacity(0.35) }
                    }
                    .clipShape(shape)
                }
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }
}
