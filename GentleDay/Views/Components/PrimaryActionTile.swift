import SwiftUI

struct PrimaryActionTile: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var accent: Color
    var background: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42, alignment: .leading)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(AppTypography.tileTitle)
                    .foregroundStyle(AppColors.navy)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.mutedText)
                    .lineSpacing(1.5)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: DesignTokens.Size.actionTileMinHeight, alignment: .topLeading)
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .fill(background)
                .shadow(color: DesignTokens.cardShadow.color, radius: 14, x: 0, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .stroke(AppColors.softBorder.opacity(0.52), lineWidth: 0.8)
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous))
    }
}
