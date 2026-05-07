import SwiftUI

enum GentleTheme {
    static let background = AppColors.background
    static let backgroundLift = AppColors.backgroundTop
    static let card = AppColors.card
    static let field = AppColors.field
    static let outline = AppColors.softBorder.opacity(0.70)
    static let ink = AppColors.navy
    static let mutedInk = AppColors.mutedText
    static let onAccent = Color.white
    static let sage = AppColors.sage
    static let butter = AppColors.butter
    static let sky = AppColors.sky
    static let peach = AppColors.peach
    static let lilac = AppColors.lavender

    static func color(for category: TaskCategory) -> Color {
        AppColors.accent(for: category)
    }

    static func softColor(for category: TaskCategory) -> Color {
        AppColors.softAccent(for: category)
    }

    static func symbol(for category: TaskCategory) -> String {
        switch category {
        case .home: "house.fill"
        case .errand: "cart.fill"
        case .family: "heart.fill"
        case .health: "cross.case.fill"
        case .money: "dollarsign"
        case .appointment: "phone.fill"
        case .meal: "fork.knife"
        case .cleaning: "tshirt.fill"
        case .personal: "person.fill"
        case .reminder: "bell.fill"
        case .habit: "sun.max.fill"
        case .other: "sparkle"
        }
    }
}

extension View {
    func gentleCardStyle() -> some View {
        modifier(SoftCardModifier())
    }

    func gentleBackground() -> some View {
        background(GentlePageBackground())
    }
}
