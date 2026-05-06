import SwiftUI

enum GentleTheme {
    static let background = Color(red: 0.06, green: 0.08, blue: 0.11)
    static let backgroundLift = Color(red: 0.09, green: 0.12, blue: 0.16)
    static let card = Color(red: 0.12, green: 0.16, blue: 0.20)
    static let field = Color(red: 0.09, green: 0.12, blue: 0.15)
    static let outline = Color.white.opacity(0.10)
    static let ink = Color(red: 0.95, green: 0.94, blue: 0.90)
    static let mutedInk = Color(red: 0.70, green: 0.75, blue: 0.76)
    static let onAccent = Color(red: 0.07, green: 0.09, blue: 0.11)
    static let sage = Color(red: 0.65, green: 0.83, blue: 0.72)
    static let butter = Color(red: 0.95, green: 0.83, blue: 0.54)
    static let sky = Color(red: 0.60, green: 0.79, blue: 0.88)
    static let peach = Color(red: 0.94, green: 0.66, blue: 0.58)
    static let lilac = Color(red: 0.77, green: 0.69, blue: 0.92)

    static func color(for category: TaskCategory) -> Color {
        switch category {
        case .home: sage
        case .errand: sky
        case .family: peach
        case .money: butter
        case .appointment: lilac
        case .cleaning: Color(red: 0.68, green: 0.84, blue: 0.75)
        case .wellness: Color(red: 0.63, green: 0.84, blue: 0.78)
        case .meals: Color(red: 0.96, green: 0.72, blue: 0.56)
        case .bills: Color(red: 0.93, green: 0.81, blue: 0.49)
        case .routine: Color(red: 0.68, green: 0.75, blue: 0.89)
        case .lifeAdmin: Color(red: 0.78, green: 0.73, blue: 0.63)
        case .other: Color(red: 0.72, green: 0.76, blue: 0.73)
        }
    }
}

extension View {
    func gentleCardStyle() -> some View {
        padding(18)
            .background(GentleTheme.card)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(GentleTheme.outline)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
    }

    func gentleBackground() -> some View {
        background(
            LinearGradient(
                colors: [
                    GentleTheme.background,
                    GentleTheme.backgroundLift
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
