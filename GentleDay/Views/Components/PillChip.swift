import SwiftUI

struct PillChip: View {
    var title: String
    var systemImage: String?
    var tint: Color = AppColors.lavender
    var background: Color?
    var isSelected: Bool = false
    var fillsWidth: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
            }

            Text(title)
                .font(AppTypography.callout.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(isSelected ? Color.white : AppColors.slate)
        .frame(maxWidth: fillsWidth ? .infinity : nil)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(isSelected ? tint : background ?? tint.opacity(0.13))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .stroke(isSelected ? Color.clear : AppColors.softBorder.opacity(0.50), lineWidth: 0.7)
        }
    }
}
