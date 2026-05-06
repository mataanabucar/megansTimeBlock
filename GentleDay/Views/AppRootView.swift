import SwiftData
import SwiftUI

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
        case .home: "house.fill"
        case .inbox: "tray.fill"
        case .plan: "calendar.badge.clock"
        case .review: "moon.stars.fill"
        case .settings: "gearshape.fill"
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
                BuildPlanView()
            }
            .tabItem { Label(AppTab.plan.title, systemImage: AppTab.plan.systemImage) }
            .tag(AppTab.plan)

            NavigationStack {
                ReviewView()
            }
            .tabItem { Label(AppTab.review.title, systemImage: AppTab.review.systemImage) }
            .tag(AppTab.review)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage) }
            .tag(AppTab.settings)
        }
        .tint(GentleTheme.sage)
        .preferredColorScheme(.dark)
        .task {
            SeedDataService.ensurePreferences(in: modelContext, existing: preferences)
        }
    }
}
