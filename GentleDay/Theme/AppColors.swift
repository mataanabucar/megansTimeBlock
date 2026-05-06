import SwiftUI

enum AppColors {
    static let background = Color(red: 0.988, green: 0.977, blue: 0.953)
    static let backgroundTop = Color(red: 0.996, green: 0.991, blue: 0.979)
    static let card = Color(red: 1.000, green: 0.998, blue: 0.989)
    static let cardLift = Color(red: 0.992, green: 0.986, blue: 0.971)
    static let field = Color(red: 0.997, green: 0.993, blue: 0.982)
    static let hairline = Color(red: 0.885, green: 0.862, blue: 0.824)
    static let softBorder = Color(red: 0.915, green: 0.894, blue: 0.858)

    static let navy = Color(red: 0.074, green: 0.144, blue: 0.255)
    static let slate = Color(red: 0.220, green: 0.250, blue: 0.315)
    static let mutedText = Color(red: 0.445, green: 0.455, blue: 0.505)
    static let faintText = Color(red: 0.590, green: 0.595, blue: 0.635)

    static let lavender = Color(red: 0.558, green: 0.497, blue: 0.822)
    static let lavenderDeep = Color(red: 0.449, green: 0.386, blue: 0.765)
    static let lavenderSoft = Color(red: 0.934, green: 0.912, blue: 0.986)
    static let lavenderMist = Color(red: 0.967, green: 0.954, blue: 0.993)

    static let sage = Color(red: 0.716, green: 0.815, blue: 0.678)
    static let sageSoft = Color(red: 0.927, green: 0.958, blue: 0.910)
    static let mint = Color(red: 0.697, green: 0.841, blue: 0.773)
    static let mintSoft = Color(red: 0.911, green: 0.964, blue: 0.939)

    static let peach = Color(red: 0.908, green: 0.582, blue: 0.496)
    static let peachSoft = Color(red: 0.996, green: 0.916, blue: 0.875)
    static let blush = Color(red: 0.918, green: 0.478, blue: 0.596)
    static let blushSoft = Color(red: 0.996, green: 0.916, blue: 0.928)

    static let sky = Color(red: 0.482, green: 0.654, blue: 0.814)
    static let skySoft = Color(red: 0.910, green: 0.947, blue: 0.984)
    static let butter = Color(red: 0.924, green: 0.733, blue: 0.363)
    static let butterSoft = Color(red: 1.000, green: 0.955, blue: 0.820)

    static let success = Color(red: 0.421, green: 0.642, blue: 0.434)
    static let warning = Color(red: 0.836, green: 0.619, blue: 0.244)

    static let pageGradient = LinearGradient(
        colors: [backgroundTop, background],
        startPoint: .top,
        endPoint: .bottom
    )

    static let primaryGradient = LinearGradient(
        colors: [lavender, lavenderDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func accent(for category: TaskCategory) -> Color {
        switch category {
        case .home: sage
        case .errand: peach
        case .family: blush
        case .money, .bills: success
        case .appointment: lavender
        case .cleaning: sky
        case .wellness: mint
        case .meals: butter
        case .routine: lavender
        case .lifeAdmin: sky
        case .other: faintText
        }
    }

    static func softAccent(for category: TaskCategory) -> Color {
        switch category {
        case .home: sageSoft
        case .errand: peachSoft
        case .family: blushSoft
        case .money, .bills: sageSoft
        case .appointment: lavenderSoft
        case .cleaning: skySoft
        case .wellness: mintSoft
        case .meals: butterSoft
        case .routine: lavenderMist
        case .lifeAdmin: skySoft
        case .other: cardLift
        }
    }
}
