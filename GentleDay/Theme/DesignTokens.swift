import SwiftUI

struct GentleShadow {
    var color: Color
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat
}

enum DesignTokens {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let screen: CGFloat = GentleLayout.pageHorizontalPadding
        static let tabReservedHeight: CGFloat = GentleLayout.tabBarSafeAreaReserve
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 30
        static let pill: CGFloat = 999
    }

    enum Size {
        static let iconCircle: CGFloat = 42
        static let smallIconCircle: CGFloat = 32
        static let actionTileMinHeight: CGFloat = 152
        static let tabBarHeight: CGFloat = GentleLayout.tabBarHeight
    }

    static let cardShadow = GentleShadow(
        color: Color(red: 0.160, green: 0.125, blue: 0.080).opacity(0.085),
        radius: 18,
        x: 0,
        y: 10
    )

    static let floatingShadow = GentleShadow(
        color: Color(red: 0.160, green: 0.125, blue: 0.080).opacity(0.140),
        radius: 22,
        x: 0,
        y: 12
    )
}

enum AppTheme {
    static var colors: AppColors.Type { AppColors.self }
    static var spacing: DesignTokens.Spacing.Type { DesignTokens.Spacing.self }
    static var radius: DesignTokens.Radius.Type { DesignTokens.Radius.self }
    static var typography: AppTypography.Type { AppTypography.self }
}
