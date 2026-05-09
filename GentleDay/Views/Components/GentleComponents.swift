import SwiftUI

// MARK: - Buttons

/// Role-based button used across all Gentle Day screens. Full-width by
/// default. Always meets the 44pt tap target.
struct GentleButton: View {
    enum Role {
        /// Soft purple fill, white label. Use for the single most important
        /// action on a screen.
        case primary
        /// Surface fill with a soft outline, navy label. Use for supporting
        /// actions next to a primary.
        case secondary
        /// No fill, no border, soft purple label. Use for inline links and
        /// optional actions.
        case tertiary
        /// Soft rose fill, navy label. Use for gentle warning actions like
        /// "Skip without guilt" — never a hard delete.
        case destructiveSoft
    }

    let title: String
    var systemImage: String? = nil
    var role: Role = .primary
    var fullWidth: Bool = true
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: GentleTheme.Spacing.sm) {
                if isLoading {
                    ProgressView().tint(foregroundColor)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                }
                Text(title)
                    .font(GentleTheme.Typography.button)
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, GentleTheme.Spacing.lg)
            .padding(.vertical, GentleTheme.Spacing.md + 2)
            .background(background)
            .overlay {
                RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            }
            .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
            .opacity(isEnabled ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }

    private var foregroundColor: Color {
        switch role {
        case .primary: return GentleTheme.onAccent
        case .secondary: return GentleTheme.textPrimary
        case .tertiary: return GentleTheme.primary
        case .destructiveSoft: return GentleTheme.textPrimary
        }
    }

    private var background: Color {
        switch role {
        case .primary: return GentleTheme.primary
        case .secondary: return GentleTheme.surface
        case .tertiary: return Color.clear
        case .destructiveSoft: return GentleTheme.dangerSoft.opacity(0.55)
        }
    }

    private var borderColor: Color {
        switch role {
        case .primary, .tertiary, .destructiveSoft: return Color.clear
        case .secondary: return GentleTheme.outline
        }
    }

    private var borderWidth: CGFloat {
        role == .secondary ? 1 : 0
    }
}

/// Backwards-compatible wrapper for existing call sites. New code should use
/// `GentleButton(role: .primary, ...)` directly.
struct GentlePrimaryButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        GentleButton(title: title, systemImage: systemImage, role: .primary, action: action)
    }
}

// MARK: - Icon badge

/// Soft-tinted rounded square holding an SF Symbol. Used as the leading
/// affordance on action cards, task cards, and section icons.
struct GentleIconBadge: View {
    enum Size {
        case small, medium, large

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        }

        var font: Font {
            switch self {
            case .small: return .system(.callout).weight(.semibold)
            case .medium: return .system(.title3).weight(.semibold)
            case .large: return .system(.title2).weight(.semibold)
            }
        }

        var radius: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return GentleTheme.Radius.chip
            case .large: return 14
            }
        }
    }

    let systemName: String
    var tint: Color = GentleTheme.primary
    var size: Size = .medium

    var body: some View {
        Image(systemName: systemName)
            .font(size.font)
            .foregroundStyle(GentleTheme.textPrimary)
            .frame(width: size.dimension, height: size.dimension)
            .background(tint.opacity(0.32))
            .clipShape(RoundedRectangle(cornerRadius: size.radius, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Chip

/// Soft pill / chip used for filter selections, metadata, and tag-style
/// affordances. Rounded-rectangle (12pt) by default — reads better than a
/// capsule against pastel cards.
struct GentleChip: View {
    let title: String
    var tint: Color = GentleTheme.primary
    var isSelected: Bool = false
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(title)
        }
        .font(GentleTheme.Typography.metadata)
        .foregroundStyle(GentleTheme.textPrimary)
        .padding(.horizontal, GentleTheme.Spacing.md)
        .padding(.vertical, GentleTheme.Spacing.sm)
        .background(isSelected ? tint.opacity(0.55) : tint.opacity(0.18))
        .overlay {
            RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous)
                .stroke(isSelected ? tint.opacity(0.85) : GentleTheme.outline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
    }
}

/// Backwards-compatible alias for existing call sites that use `GentlePill`.
typealias GentlePill = GentleChip

// MARK: - Section header

struct GentleSectionHeader: View {
    var title: String
    var subtitle: String?
    private let trailingView: AnyView?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailingView = nil
    }

    init<TrailingView: View>(title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> TrailingView) {
        self.title = title
        self.subtitle = subtitle
        self.trailingView = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(GentleTheme.Typography.title)
                    .foregroundStyle(GentleTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(GentleTheme.Typography.subheadline)
                        .foregroundStyle(GentleTheme.textSecondary)
                }
            }
            Spacer(minLength: GentleTheme.Spacing.sm)
            if let trailingView { trailingView }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card container

/// Generic Gentle Day card. Wrap any content; optionally show a colored
/// accent stripe on the leading edge for category coding.
struct GentleCard<Content: View>: View {
    enum Elevation { case flat, standard, elevated }

    var leadingAccent: Color? = nil
    var cornerRadius: CGFloat = GentleTheme.Radius.card
    var elevation: Elevation = .standard
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            if let leadingAccent {
                Rectangle()
                    .fill(leadingAccent)
                    .frame(width: 4)
                    .accessibilityHidden(true)
            }
            content()
                .padding(GentleTheme.Spacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(GentleTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(GentleTheme.outline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: shadowY
        )
    }

    private var shadowColor: Color {
        switch elevation {
        case .flat: return .clear
        case .standard: return GentleTheme.Shadow.cardColor
        case .elevated: return GentleTheme.Shadow.elevatedColor
        }
    }

    private var shadowRadius: CGFloat {
        switch elevation {
        case .flat: return 0
        case .standard: return GentleTheme.Shadow.cardRadius
        case .elevated: return GentleTheme.Shadow.elevatedRadius
        }
    }

    private var shadowY: CGFloat {
        switch elevation {
        case .flat: return 0
        case .standard: return GentleTheme.Shadow.cardYOffset
        case .elevated: return GentleTheme.Shadow.elevatedYOffset
        }
    }
}

// MARK: - Action card (Home)

/// Big tappable card used for the four Home actions. Renders an icon badge,
/// a title, and a subtitle.
struct GentleActionCard: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            GentleIconBadge(systemName: systemImage, tint: tint, size: .medium)

            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xs) {
                Text(title)
                    .font(GentleTheme.Typography.headline)
                    .foregroundStyle(GentleTheme.textPrimary)
                Text(subtitle)
                    .font(GentleTheme.Typography.subheadline)
                    .foregroundStyle(GentleTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gentleCardStyle()
    }
}

// MARK: - Mode card

/// Selectable mode card used for Minimum Day / Ideal Plan and the Build My
/// Day style picker. When selected, fills with `tint` and shows a checkmark.
struct GentleModeCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = GentleTheme.primary
    var isSelected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: GentleTheme.Spacing.md) {
                GentleIconBadge(systemName: systemImage, tint: tint, size: .medium)

                VStack(alignment: .leading, spacing: GentleTheme.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(GentleTheme.Typography.headline)
                            .foregroundStyle(GentleTheme.textPrimary)
                        Spacer(minLength: GentleTheme.Spacing.sm)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.medium)
                                .foregroundStyle(tint)
                                .accessibilityHidden(true)
                        }
                    }
                    Text(subtitle)
                        .font(GentleTheme.Typography.subheadline)
                        .foregroundStyle(GentleTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GentleTheme.Spacing.cardPadding)
            .background(isSelected ? tint.opacity(0.18) : GentleTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.7) : GentleTheme.outline, lineWidth: isSelected ? 1.5 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous))
            .shadow(color: GentleTheme.Shadow.cardColor, radius: GentleTheme.Shadow.cardRadius, x: 0, y: GentleTheme.Shadow.cardYOffset)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Task card

struct GentleTaskAction: Identifiable {
    enum Role { case primary, secondary, destructive }

    let id = UUID()
    let title: String
    let systemImage: String?
    var role: Role = .secondary
    let action: () -> Void

    init(title: String, systemImage: String? = nil, role: Role = .secondary, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }
}

/// Reusable task card. Compact shows the essentials (icon, title, metadata,
/// primary action). Full also shows the tiny step and a richer action row.
struct GentleTaskCard: View {
    enum Layout { case compact, full }

    let task: TaskItem
    var layout: Layout = .compact
    var primaryAction: GentleTaskAction? = nil
    var secondaryActions: [GentleTaskAction] = []
    var overflowActions: [GentleTaskAction] = []

    var body: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            HStack(alignment: .top, spacing: GentleTheme.Spacing.md) {
                GentleIconBadge(
                    systemName: GentleTaskCard.icon(for: task.category),
                    tint: GentleTheme.color(for: task.category),
                    size: layout == .full ? .large : .medium
                )

                VStack(alignment: .leading, spacing: GentleTheme.Spacing.sm) {
                    Text(task.title)
                        .font(layout == .full ? GentleTheme.Typography.title : GentleTheme.Typography.headline)
                        .foregroundStyle(GentleTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    GentleMetadataRow(items: metadata)
                }

                Spacer(minLength: 0)

                if !overflowActions.isEmpty {
                    overflowMenu
                }
            }

            if layout == .full, !task.suggestedTinyStep.isEmpty {
                tinyStepBox
            }

            if primaryAction != nil || !secondaryActions.isEmpty {
                actionRow
            }
        }
        .gentleCardStyle()
    }

    // MARK: subviews

    @ViewBuilder
    private var actionRow: some View {
        VStack(spacing: GentleTheme.Spacing.sm) {
            if let primaryAction {
                taskActionButton(primaryAction)
            }
            if !secondaryActions.isEmpty {
                HStack(spacing: GentleTheme.Spacing.sm) {
                    ForEach(secondaryActions) { action in
                        taskActionButton(action)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func taskActionButton(_ action: GentleTaskAction) -> some View {
        let role: GentleButton.Role = {
            switch action.role {
            case .primary: return .primary
            case .secondary: return .secondary
            case .destructive: return .destructiveSoft
            }
        }()
        GentleButton(
            title: action.title,
            systemImage: action.systemImage,
            role: role,
            fullWidth: true,
            action: action.action
        )
    }

    private var overflowMenu: some View {
        Menu {
            ForEach(overflowActions) { action in
                Button(role: action.role == .destructive ? .destructive : nil, action: action.action) {
                    if let icon = action.systemImage {
                        Label(action.title, systemImage: icon)
                    } else {
                        Text(action.title)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3.weight(.semibold))
                .foregroundStyle(GentleTheme.textSecondary)
                .frame(width: 36, height: 36)
                .background(GentleTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .accessibilityLabel("More actions")
    }

    private var tinyStepBox: some View {
        HStack(alignment: .top, spacing: GentleTheme.Spacing.sm) {
            Image(systemName: "leaf.fill")
                .imageScale(.small)
                .foregroundStyle(GentleTheme.textPrimary)
                .padding(6)
                .background(GentleTheme.sage.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tiny step")
                    .font(GentleTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(GentleTheme.textSecondary)
                Text(task.suggestedTinyStep)
                    .font(GentleTheme.Typography.subheadline)
                    .foregroundStyle(GentleTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GentleTheme.Spacing.md)
        .background(GentleTheme.sage.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
    }

    private var metadata: [String] {
        var items: [String] = [task.category.title, "\(task.estimatedMinutes) min"]
        if let due = task.dueDate {
            items.append("Due \(DateFormatting.shortDate.string(from: due))")
        } else if let window = task.flexibleWindow, !window.isEmpty {
            items.append(window)
        }
        if layout == .full {
            items.append(task.energyLevel.title)
        }
        if task.status != .inbox && task.status != .scheduled {
            items.append(task.status.title)
        }
        return items
    }

    static func icon(for category: TaskCategory) -> String {
        switch category {
        case .home: "house.fill"
        case .errand: "bag.fill"
        case .family: "person.2.fill"
        case .money: "dollarsign.circle.fill"
        case .appointment: "calendar"
        case .cleaning: "sparkles"
        case .wellness: "heart.fill"
        case .meals: "fork.knife"
        case .bills: "doc.text.fill"
        case .routine: "repeat"
        case .lifeAdmin: "tray.fill"
        case .other: "circle.fill"
        }
    }
}

// MARK: - Time block card

/// Container for a flexible window (Morning / Afternoon / Evening / Before
/// bed) on the Today screen. Tappable header with an expandable body.
struct GentleTimeBlockCard<Content: View>: View {
    let title: String
    let timeRange: String
    let systemImage: String
    var tint: Color = GentleTheme.primary
    let taskCount: Int
    var isCurrent: Bool = false
    var isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: GentleTheme.Spacing.md) {
                    GentleIconBadge(systemName: systemImage, tint: tint, size: .medium)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: GentleTheme.Spacing.sm) {
                            Text(title)
                                .font(GentleTheme.Typography.headline)
                                .foregroundStyle(GentleTheme.textPrimary)
                            if isCurrent {
                                Text("Now")
                                    .font(GentleTheme.Typography.caption.weight(.bold))
                                    .foregroundStyle(GentleTheme.onAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(GentleTheme.primary)
                                    .clipShape(Capsule())
                                    .accessibilityLabel("Current window")
                            }
                        }
                        Text("\(timeRange) · \(taskCount) \(taskCount == 1 ? "task" : "tasks")")
                            .font(GentleTheme.Typography.caption)
                            .foregroundStyle(GentleTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                        .foregroundStyle(GentleTheme.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(GentleTheme.Spacing.cardPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
                    content()
                }
                .padding(.horizontal, GentleTheme.Spacing.cardPadding)
                .padding(.bottom, GentleTheme.Spacing.cardPadding)
            }
        }
        .background(GentleTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous)
                .stroke(isCurrent ? GentleTheme.primary.opacity(0.6) : GentleTheme.outline, lineWidth: isCurrent ? 1.5 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous))
        .shadow(color: GentleTheme.Shadow.cardColor, radius: GentleTheme.Shadow.cardRadius, x: 0, y: GentleTheme.Shadow.cardYOffset)
    }
}

// MARK: - Empty state

struct GentleEmptyState: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        VStack(spacing: GentleTheme.Spacing.md) {
            GentleIconBadge(systemName: systemImage, tint: GentleTheme.primary, size: .large)
            Text(title)
                .font(GentleTheme.Typography.headline)
                .foregroundStyle(GentleTheme.textPrimary)
            Text(message)
                .font(GentleTheme.Typography.subheadline)
                .foregroundStyle(GentleTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .gentleCardStyle()
    }
}

// MARK: - Metadata row

struct GentleMetadataRow: View {
    var items: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items.filter { !$0.isEmpty }, id: \.self) { item in
                Text(item)
                    .font(GentleTheme.Typography.metadata)
                    .foregroundStyle(GentleTheme.textSecondary)
                    .padding(.horizontal, GentleTheme.Spacing.sm + 1)
                    .padding(.vertical, 4)
                    .background(GentleTheme.field)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(GentleTheme.outline, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

// MARK: - Bottom safe-area helper

extension View {
    /// Adds bottom padding equal to `Spacing.bottomSafeBleed` so that scrolled
    /// content always clears the tab bar. Apply to the inner VStack of every
    /// scrollable screen.
    func gentleBottomSafePad() -> some View {
        padding(.bottom, GentleTheme.Spacing.bottomSafeBleed)
    }
}
