import SwiftUI

struct StyleOptionCard: View {
    let style: PosterStyle
    let thumbnail: UIImage?
    let isSelected: Bool
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [accent.opacity(0.75), Color(hex: "#38BDF8").opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: 58, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr(style.titleKey))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(L10n.tr(style.descKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? accent : Color.secondary.opacity(0.35))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .liquidGlassRoundedRect(
                cornerRadius: 16,
                tint: isSelected ? accent.opacity(0.16) : nil,
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ColorPresetSwatchButton: View {
    let preset: ColorPreset
    let isSelected: Bool
    let accent: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            let bgColor: Color = preset.bgMode == .white ? .white : Color(hex: preset.bgHex)
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(bgColor)

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: preset.swatchDots[0])).frame(width: 9, height: 9)
                        Circle().fill(Color(hex: preset.swatchDots[1])).frame(width: 7, height: 7)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: preset.swatchDots[2])).frame(width: 7, height: 7)
                        Circle().fill(Color(hex: preset.swatchDots[3])).frame(width: 9.5, height: 9.5)
                    }
                }
            }
            .frame(width: 38, height: 38)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? accent : Color.primary.opacity(0.16), lineWidth: isSelected ? 2.2 : 0.8)
            )
            .shadow(color: isSelected ? accent.opacity(0.30) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }
}
