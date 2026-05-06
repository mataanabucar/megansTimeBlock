import SwiftUI

struct SoftCard<Content: View>: View {
    var background: Color
    var stroke: Color
    var cornerRadius: CGFloat
    var innerPadding: CGFloat
    var shadow: GentleShadow
    var content: Content

    init(
        background: Color = AppColors.card,
        stroke: Color = AppColors.softBorder.opacity(0.72),
        cornerRadius: CGFloat = DesignTokens.Radius.xl,
        innerPadding: CGFloat = DesignTokens.Spacing.lg,
        shadow: GentleShadow = DesignTokens.cardShadow,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.stroke = stroke
        self.cornerRadius = cornerRadius
        self.innerPadding = innerPadding
        self.shadow = shadow
        self.content = content()
    }

    var body: some View {
        content
            .padding(innerPadding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
                    .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 0.8)
            }
    }
}

struct SoftCardModifier: ViewModifier {
    var background: Color = AppColors.card
    var cornerRadius: CGFloat = DesignTokens.Radius.xl
    var innerPadding: CGFloat = DesignTokens.Spacing.lg

    func body(content: Content) -> some View {
        content
            .padding(innerPadding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
                    .shadow(
                        color: DesignTokens.cardShadow.color,
                        radius: DesignTokens.cardShadow.radius,
                        x: DesignTokens.cardShadow.x,
                        y: DesignTokens.cardShadow.y
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.softBorder.opacity(0.72), lineWidth: 0.8)
            }
    }
}

struct GentlePageBackground: View {
    var body: some View {
        AppColors.pageGradient
            .ignoresSafeArea()
    }
}

struct SoftIconButton: View {
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.navy)
                .frame(width: 36, height: 36)
                .background(AppColors.card.opacity(0.94))
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(AppColors.softBorder.opacity(0.65), lineWidth: 0.8)
                }
                .shadow(color: DesignTokens.cardShadow.color, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct CategoryIconBadge: View {
    var category: TaskCategory
    var size: CGFloat = DesignTokens.Size.iconCircle

    var body: some View {
        Image(systemName: GentleTheme.symbol(for: category))
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(AppColors.accent(for: category))
            .frame(width: size, height: size)
            .background(AppColors.softAccent(for: category))
            .clipShape(Circle())
    }
}
