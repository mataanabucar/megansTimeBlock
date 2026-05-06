import SwiftUI

enum AppTypography {
    static func display(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let heroTitle = Font.system(size: 34, weight: .regular, design: .serif)
    static let pageTitle = Font.system(size: 31, weight: .regular, design: .serif)
    static let cardTitle = Font.system(size: 18, weight: .semibold, design: .default)
    static let tileTitle = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let bodyEmphasis = Font.system(size: 15, weight: .semibold, design: .default)
    static let callout = Font.system(size: 14, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
    static let tabLabel = Font.system(size: 10, weight: .medium, design: .default)
}
