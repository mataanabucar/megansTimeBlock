import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case inbox
    case today
    case plan
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .inbox: "Inbox"
        case .today: "Today"
        case .plan: "Plan"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .inbox: "tray.fill"
        case .today: "sun.max.fill"
        case .plan: "wand.and.stars"
        case .more: "ellipsis.circle.fill"
        }
    }
}

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPlanningPreferences]
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
            .tag(AppTab.home)

            NavigationStack {
                InboxView()
            }
            .tabItem { Label(AppTab.inbox.title, systemImage: AppTab.inbox.systemImage) }
            .tag(AppTab.inbox)

            NavigationStack {
                TodayScheduleView()
            }
            .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.systemImage) }
            .tag(AppTab.today)

            NavigationStack {
                BuildPlanView()
            }
            .tabItem { Label(AppTab.plan.title, systemImage: AppTab.plan.systemImage) }
            .tag(AppTab.plan)

            NavigationStack {
                MoreView()
            }
            .tabItem { Label(AppTab.more.title, systemImage: AppTab.more.systemImage) }
            .tag(AppTab.more)
        }
        .tint(GentleTheme.primary)
        .preferredColorScheme(.light)
        .task {
            SeedDataService.ensurePreferences(in: modelContext, existing: preferences)
        }
    }
}

// MARK: - More tab

/// The "More" tab is a lightweight hub for screens that don't earn their own
/// tab — Review and Settings today. Kept as a private struct in this file so
/// no new file needs to be wired into the Xcode project.
private struct MoreView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.lg) {
                GentleSectionHeader(
                    title: "More",
                    subtitle: "Reflection, settings, and other gentle tools."
                )

                VStack(spacing: GentleTheme.Spacing.md) {
                    NavigationLink {
                        ReviewView()
                    } label: {
                        MoreRow(
                            title: "Gentle Review",
                            subtitle: "End-of-day reflection. Compassion, not scoring.",
                            systemImage: "moon.stars.fill",
                            tint: GentleTheme.lilac
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SettingsView()
                    } label: {
                        MoreRow(
                            title: "Settings",
                            subtitle: "Times, reminders, and AI parsing.",
                            systemImage: "gearshape.fill",
                            tint: GentleTheme.sky
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("Be kind. Small steps count.")
                    .font(GentleTheme.Typography.compassionate)
                    .foregroundStyle(GentleTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, GentleTheme.Spacing.lg)
            }
            .padding(GentleTheme.Spacing.screenHorizontal)
            .gentleBottomSafePad()
        }
        .gentleBackground()
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MoreRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: GentleTheme.Spacing.md) {
            GentleIconBadge(systemName: systemImage, tint: tint, size: .medium)
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xs) {
                Text(title)
                    .font(GentleTheme.Typography.headline)
                    .foregroundStyle(GentleTheme.textPrimary)
                Text(subtitle)
                    .font(GentleTheme.Typography.subheadline)
                    .foregroundStyle(GentleTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .imageScale(.small)
                .foregroundStyle(GentleTheme.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(GentleTheme.Spacing.cardPadding)
        .background(GentleTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous)
                .stroke(GentleTheme.outline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous))
        .shadow(color: GentleTheme.Shadow.cardColor, radius: GentleTheme.Shadow.cardRadius, x: 0, y: GentleTheme.Shadow.cardYOffset)
    }
}
