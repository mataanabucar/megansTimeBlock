import SwiftUI

private struct GentleActiveTabKey: EnvironmentKey {
    static let defaultValue: Binding<AppTab>? = nil
}

extension EnvironmentValues {
    var gentleActiveTab: Binding<AppTab>? {
        get { self[GentleActiveTabKey.self] }
        set { self[GentleActiveTabKey.self] = newValue }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case inbox
    case plan
    case review
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .inbox: "Inbox"
        case .plan: "Plan"
        case .review: "Review"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .inbox: "tray"
        case .plan: "calendar"
        case .review: "sparkles"
        case .settings: "ellipsis"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .home: "house.fill"
        case .inbox: "tray.fill"
        case .plan: "calendar.badge.clock"
        case .review: "sparkles"
        case .settings: "ellipsis"
        }
    }
}

struct GentleTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 7) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    tabItem(tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: GentleLayout.tabBarHeight)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColors.card.opacity(0.96))
                .shadow(
                    color: DesignTokens.floatingShadow.color,
                    radius: DesignTokens.floatingShadow.radius,
                    x: DesignTokens.floatingShadow.x,
                    y: DesignTokens.floatingShadow.y
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppColors.softBorder.opacity(0.65), lineWidth: 0.8)
        }
    }

    @ViewBuilder
    private func tabItem(_ tab: AppTab) -> some View {
        if selection == tab {
            HStack(spacing: 7) {
                Image(systemName: tab.selectedSystemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(AppColors.lavenderDeep)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(AppColors.lavenderSoft)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 17, weight: .medium))
                Text(tab.title)
                    .font(AppTypography.tabLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(AppColors.mutedText)
            .frame(maxWidth: .infinity)
        }
    }
}
