import SwiftUI

struct GentleActionCard: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color

    var body: some View {
        PrimaryActionTile(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            accent: tint,
            background: tint.opacity(0.13)
        )
    }
}

struct GentleSectionHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        SectionTitleView(title: title, subtitle: subtitle)
    }
}

struct GentlePill: View {
    var title: String
    var tint: Color = GentleTheme.sage
    var isSelected: Bool = false

    var body: some View {
        PillChip(title: title, tint: tint, isSelected: isSelected)
    }
}

struct GentleEmptyState: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        SoftCard {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(AppColors.lavender)
                    .frame(width: 54, height: 54)
                    .background(AppColors.lavenderSoft)
                    .clipShape(Circle())

                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.navy)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.mutedText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct GentleLogoMark: View {
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.butterSoft)

            VStack(spacing: -1) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: size * 0.30, weight: .medium))
                    .foregroundStyle(AppColors.butter)
                Image(systemName: "water.waves")
                    .font(.system(size: size * 0.30, weight: .semibold))
                    .foregroundStyle(AppColors.sky)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .stroke(AppColors.card.opacity(0.75), lineWidth: 2)
        }
    }
}

struct GentlePrimaryButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.primaryGradient)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                .shadow(color: AppColors.lavender.opacity(0.22), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

struct GentleMetadataRow: View {
    var items: [String]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(items.filter { !$0.isEmpty }, id: \.self) { item in
                Text(item)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.mutedText)
            }
        }
    }
}
