import SwiftUI

/// Crisp vector Liquid Glass PosterCut / Mosaika mark adapting naturally to Light and Dark Mode.
struct PosterMarkView: View {
    var size: CGFloat = 64
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let corner = size * 0.225
        let pad = size * 0.16
        let gap = size * 0.065
        let tile = (size - pad * 2 - gap) * 0.5
        let tileCorner = tile * 0.19

        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color(hex: "#0D2B54"), Color(hex: "#051228")]
                            : [Color(hex: "#F2F8FF"), Color(hex: "#DCEBFF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(colorScheme == .dark ? 0.22 : 0.75), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(0.8, size * 0.015)
                        )
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: size * 0.10, y: size * 0.05)

            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    tileRect(tile: tile, corner: tileCorner, colors: [Color(hex: "#3E82DC"), Color(hex: "#0659C2")])
                    tileRect(tile: tile, corner: tileCorner, colors: [Color(hex: "#69FAFF"), Color(hex: "#06C3FD")])
                }
                HStack(spacing: gap) {
                    tileRect(tile: tile, corner: tileCorner, colors: [Color(hex: "#5676C8"), Color(hex: "#153A9F")])
                    tileRect(tile: tile, corner: tileCorner, colors: [Color(hex: "#B5E6FA"), Color(hex: "#58B4E7")])
                }
            }
            .padding(pad)

            // Luminous precision cut cross
            ZStack {
                Capsule()
                    .fill(colorScheme == .dark ? Color(hex: "#8DFCFF") : Color(hex: "#0EA5E9"))
                    .frame(width: max(2.2, size * 0.036), height: size * 0.70)
                    .shadow(color: Color(hex: "#38BDF8").opacity(0.75), radius: size * 0.05)
                Capsule()
                    .fill(colorScheme == .dark ? Color(hex: "#8DFCFF") : Color(hex: "#0EA5E9"))
                    .frame(width: size * 0.70, height: max(2.2, size * 0.036))
                    .shadow(color: Color(hex: "#38BDF8").opacity(0.75), radius: size * 0.05)
            }
        }
        .frame(width: size, height: size)
    }

    private func tileRect(tile: CGFloat, corner: CGFloat, colors: [Color]) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.32), lineWidth: 0.7)
            )
            .frame(width: tile, height: tile)
    }
}
