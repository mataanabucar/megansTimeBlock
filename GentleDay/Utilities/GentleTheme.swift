import SwiftUI

enum GentleTheme {
    static let background = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let card = Color(red: 1.0, green: 0.99, blue: 0.96)
    static let ink = Color(red: 0.22, green: 0.25, blue: 0.25)
    static let mutedInk = Color(red: 0.45, green: 0.49, blue: 0.49)
    static let sage = Color(red: 0.67, green: 0.76, blue: 0.64)
    static let butter = Color(red: 0.96, green: 0.83, blue: 0.52)
    static let sky = Color(red: 0.69, green: 0.82, blue: 0.88)
    static let peach = Color(red: 0.94, green: 0.67, blue: 0.55)
    static let lilac = Color(red: 0.78, green: 0.73, blue: 0.86)

    static func color(for category: TaskCategory) -> Color {
        switch category {
        case .home: sage
        case .errand: sky
        case .family: peach
        case .money: butter
        case .appointment: lilac
        case .cleaning: Color(red: 0.74, green: 0.84, blue: 0.78)
        case .wellness: Color(red: 0.70, green: 0.83, blue: 0.77)
        case .meals: Color(red: 0.95, green: 0.77, blue: 0.61)
        case .bills: Color(red: 0.93, green: 0.83, blue: 0.54)
        case .routine: Color(red: 0.76, green: 0.80, blue: 0.88)
        case .lifeAdmin: Color(red: 0.82, green: 0.78, blue: 0.68)
        case .other: Color(red: 0.80, green: 0.82, blue: 0.78)
        }
    }
}

extension View {
    func gentleCardStyle() -> some View {
        padding(18)
            .background(GentleTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
    }

    func gentleBackground() -> some View {
        background(
            LinearGradient(
                colors: [
                    GentleTheme.background,
                    Color(red: 0.94, green: 0.96, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

