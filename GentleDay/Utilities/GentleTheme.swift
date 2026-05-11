import SwiftUI

// MARK: - Theme

/// Gentle Day's design tokens. Light-mode pastel palette with deep-navy text
/// and a soft-purple primary. All values are exposed both as flat shortcuts
/// (`GentleTheme.sage`, `GentleTheme.card`) for compatibility with existing
/// call sites and as nested token namespaces (`GentleTheme.Spacing.lg`,
/// `GentleTheme.Typography.title`, `GentleTheme.Radius.card`,
/// `GentleTheme.Shadow.cardColor`) for new code.
enum GentleTheme {

    // MARK: Colors

    /// Warm off-white app background.
    static let background = Color(red: 0.98, green: 0.97, blue: 0.95)
    /// Slightly lighter warm tint behind grouped content.
    static let backgroundLift = Color(red: 0.99, green: 0.98, blue: 0.96)
    /// Near-white surface for standard cards.
    static let surface = Color(red: 0.995, green: 0.985, blue: 0.97)
    /// Pure white surface for modals / elevated cards.
    static let elevatedSurface = Color.white
    /// Legacy alias for `surface` — keep so old call sites compile.
    static let card = surface
    /// Soft input-field background, faintly lavender so it reads as interactive.
    static let field = Color(red: 0.965, green: 0.955, blue: 0.975)
    /// Soft lavender-gray border.
    static let outline = Color(red: 0.90, green: 0.87, blue: 0.93)
    /// Slightly stronger border (use sparingly).
    static let outlineStrong = Color(red: 0.84, green: 0.81, blue: 0.89)

    /// Deep navy — primary text.
    static let textPrimary = Color(red: 0.105, green: 0.122, blue: 0.227)
    /// Legacy alias for `textPrimary`.
    static let ink = textPrimary
    /// Muted blue-gray — secondary text.
    static let textSecondary = Color(red: 0.36, green: 0.385, blue: 0.50)
    /// Legacy alias for `textSecondary`.
    static let mutedInk = textSecondary
    /// Color used on top of a saturated accent fill (white reads well).
    static let onAccent = Color.white

    /// Soft purple — primary action color.
    static let primary = Color(red: 0.605, green: 0.545, blue: 0.85)
    /// Deep violet — pressed primary / strong contrast variant.
    static let primaryDark = Color(red: 0.42, green: 0.365, blue: 0.715)

    // Pastel accent palette
    /// Soft sage green.
    static let sage = Color(red: 0.715, green: 0.83, blue: 0.72)
    /// Soft sky blue.
    static let sky = Color(red: 0.75, green: 0.85, blue: 0.91)
    /// Soft peach.
    static let peach = Color(red: 0.957, green: 0.788, blue: 0.71)
    /// Soft rose pink.
    static let rose = Color(red: 0.937, green: 0.757, blue: 0.788)
    /// Light lavender (distinct from `primary`).
    static let lilac = Color(red: 0.84, green: 0.788, blue: 0.93)
    /// Soft sun yellow.
    static let butter = Color(red: 0.965, green: 0.886, blue: 0.66)
    /// Soft rose-red for gentle warnings.
    static let dangerSoft = Color(red: 0.91, green: 0.69, blue: 0.69)

    /// Color mapping for each task category. Pastels chosen to read well next
    /// to deep-navy text on the warm off-white background.
    static func color(for category: TaskCategory) -> Color {
        switch category {
        case .steadyRoutine: Color(red: 0.78, green: 0.82, blue: 0.92)
        case .home: sage
        case .errand: sky
        case .family: peach
        case .money: butter
        case .appointment: lilac
        case .cleaning: Color(red: 0.74, green: 0.86, blue: 0.78)
        case .wellness: Color(red: 0.71, green: 0.86, blue: 0.84)
        case .meals: Color(red: 0.97, green: 0.82, blue: 0.69)
        case .bills: Color(red: 0.96, green: 0.86, blue: 0.62)
        case .routine: Color(red: 0.78, green: 0.82, blue: 0.92)
        case .lifeAdmin: Color(red: 0.88, green: 0.84, blue: 0.78)
        case .other: Color(red: 0.86, green: 0.85, blue: 0.86)
        }
    }

    // MARK: Spacing

    /// 4/8pt grid spacing tokens. Use these instead of magic numbers.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let xxxl: CGFloat = 40
        /// Standard horizontal padding for full-width screens.
        static let screenHorizontal: CGFloat = 20
        /// Standard inner padding for cards.
        static let cardPadding: CGFloat = 18
        /// Bleed kept clear at the bottom of any scroll view so the tab bar
        /// never covers content. Tuned for iPhone 15 / SE.
        static let bottomSafeBleed: CGFloat = 96
        /// Reserved height used when laying out pinned bottom CTAs.
        static let tabBarReserve: CGFloat = 64
    }

    // MARK: Radius

    enum Radius {
        static let chip: CGFloat = 12
        static let card: CGFloat = 20
        static let cardLarge: CGFloat = 24
        static let pill: CGFloat = 999
    }

    // MARK: Typography

    /// Type tokens. Always built on `Font.system(...)` so Dynamic Type works
    /// without per-call-site changes.
    enum Typography {
        /// Massive landing-style display.
        static let displayLarge = Font.system(.largeTitle, design: .rounded).weight(.bold)
        /// Smaller display.
        static let displayMedium = Font.system(.title, design: .rounded).weight(.semibold)
        /// Title for screens / cards.
        static let title = Font.system(.title2, design: .rounded).weight(.semibold)
        /// Section headers and prominent labels.
        static let headline = Font.system(.headline)
        /// Body copy.
        static let body = Font.system(.body)
        /// Body copy with weight for emphasis.
        static let bodyEmphasized = Font.system(.body).weight(.semibold)
        /// Subtle subheadings.
        static let subheadline = Font.system(.subheadline)
        /// Compact metadata.
        static let caption = Font.system(.caption)
        /// Compact metadata with weight.
        static let metadata = Font.system(.caption).weight(.medium)
        /// Standard button label.
        static let button = Font.system(.headline)
        /// Italic, gentle microcopy used for footers and reassurance.
        static let compassionate = Font.system(.subheadline).italic()
    }

    // MARK: Shadow

    /// Light-mode-friendly shadow tokens. Resolve via `.shadow(...)` directly,
    /// e.g. `.shadow(color: GentleTheme.Shadow.cardColor,
    ///                radius: GentleTheme.Shadow.cardRadius,
    ///                y: GentleTheme.Shadow.cardYOffset)`.
    enum Shadow {
        static let cardColor = Color(red: 0.105, green: 0.122, blue: 0.227).opacity(0.06)
        static let elevatedColor = Color(red: 0.105, green: 0.122, blue: 0.227).opacity(0.10)
        static let subtleColor = Color(red: 0.105, green: 0.122, blue: 0.227).opacity(0.04)
        static let cardRadius: CGFloat = 12
        static let elevatedRadius: CGFloat = 20
        static let subtleRadius: CGFloat = 6
        static let cardYOffset: CGFloat = 6
        static let elevatedYOffset: CGFloat = 10
        static let subtleYOffset: CGFloat = 2
    }
}

// MARK: - Card / Background Modifiers

extension View {
    /// Standard Gentle Day card surface: padding, soft shadow, soft border,
    /// rounded corner. Tokens-driven so it stays consistent across screens.
    func gentleCardStyle(cornerRadius: CGFloat = GentleTheme.Radius.card) -> some View {
        modifier(GentleCardStyleModifier(cornerRadius: cornerRadius))
    }

    /// Warm off-white app background. Ignores safe area so edge bleed is clean.
    func gentleBackground() -> some View {
        background(GentleTheme.background.ignoresSafeArea())
    }
}

private struct GentleCardStyleModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(GentleTheme.Spacing.cardPadding)
            .background(GentleTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GentleTheme.outline, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: GentleTheme.Shadow.cardColor,
                radius: GentleTheme.Shadow.cardRadius,
                x: 0,
                y: GentleTheme.Shadow.cardYOffset
            )
    }
}
