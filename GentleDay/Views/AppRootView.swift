import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPlanningPreferences]
    @State private var selectedTab: AppTab = .home
    @State private var highlightedTab: AppTab = .home
    @State private var tabResetID = UUID()

    var body: some View {
        ZStack {
            GentlePageBackground()

            VStack(spacing: 0) {
                activeTabContent
                    .environment(\.gentleActiveTab, highlightedTabBinding)
                    .id("\(selectedTab.rawValue)-\(tabResetID.uuidString)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                GentleTabBar(selection: tabBarSelection)
                    .padding(.horizontal, GentleLayout.tabBarHorizontalPadding)
                    .padding(.bottom, GentleLayout.tabBarBottomPadding)
            }
        }
        .tint(AppColors.lavenderDeep)
        .preferredColorScheme(.light)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: selectedTab)
        .task {
            SeedDataService.ensurePreferences(in: modelContext, existing: preferences)
        }
    }

    private var highlightedTabBinding: Binding<AppTab> {
        Binding(
            get: { highlightedTab },
            set: { highlightedTab = $0 }
        )
    }

    private var tabBarSelection: Binding<AppTab> {
        Binding(
            get: { highlightedTab },
            set: { tab in
                highlightedTab = tab
                if selectedTab == tab {
                    tabResetID = UUID()
                } else {
                    selectedTab = tab
                }
            }
        )
    }

    @ViewBuilder
    private var activeTabContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack {
                HomeView()
            }
        case .inbox:
            NavigationStack {
                InboxView()
            }
        case .plan:
            NavigationStack {
                TodayScheduleView()
            }
        case .review:
            NavigationStack {
                ReviewView()
            }
        case .settings:
            NavigationStack {
                SettingsView()
            }
        }
    }
}
