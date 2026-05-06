import SwiftData
import SwiftUI

private struct HomeFocusEntry: Identifiable {
    var title: String
    var category: TaskCategory

    var id: String { "\(title)-\(category.rawValue)" }
}

struct HomeView: View {
    @Environment(\.gentleActiveTab) private var gentleActiveTab
    @Query private var tasks: [TaskItem]
    @Query private var blocks: [ScheduleBlock]
    @State private var isShowingQuickCapture = false

    private var todayBlocks: [ScheduleBlock] {
        blocks
            .filter { Calendar.current.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    private var nextBlock: ScheduleBlock? {
        todayBlocks.first { [.planned, .inProgress, .snoozed, .moved].contains($0.status) }
    }

    private var focusEntries: [HomeFocusEntry] {
        let blockEntries = todayBlocks
            .filter { $0.status != .done && $0.status != .skipped }
            .prefix(3)
            .map { HomeFocusEntry(title: $0.title, category: $0.category) }

        if !blockEntries.isEmpty {
            return Array(blockEntries)
        }

        let taskEntries = tasks
            .filter { $0.status == .inbox || $0.status == .shrunk }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(3)
            .map { HomeFocusEntry(title: $0.title, category: $0.category) }

        if !taskEntries.isEmpty {
            return Array(taskEntries)
        }

        return [
            HomeFocusEntry(title: "Pay electric bill", category: .money),
            HomeFocusEntry(title: "Start laundry", category: .cleaning),
            HomeFocusEntry(title: "Pick up groceries", category: .errand)
        ]
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        GentleScrollView(spacing: 22) {
            HomeGreetingHeader(greeting: greeting)
            actionGrid
            TodayFocusCard(entries: focusEntries)
            NextBlockSummaryCard(block: nextBlock)
        }
        .gentleBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            gentleActiveTab?.wrappedValue = .home
        }
        .fullScreenCover(isPresented: $isShowingQuickCapture) {
            NavigationStack {
                QuickCaptureView()
            }
        }
    }

    private var actionGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 14
        ) {
            Button {
                isShowingQuickCapture = true
            } label: {
                PrimaryActionTile(
                    title: "Capture Something",
                    subtitle: "Get it out of your head",
                    systemImage: "plus.circle",
                    accent: AppColors.lavenderDeep,
                    background: AppColors.lavenderSoft
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                NextActionView()
            } label: {
                PrimaryActionTile(
                    title: "What Should I Do Next?",
                    subtitle: "Get a gentle suggestion",
                    systemImage: "sun.max",
                    accent: AppColors.sage,
                    background: AppColors.sageSoft
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                OverwhelmedView()
            } label: {
                PrimaryActionTile(
                    title: "I'm Overwhelmed",
                    subtitle: "Reset and regulate",
                    systemImage: "cloud",
                    accent: AppColors.peach,
                    background: AppColors.peachSoft
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                BuildPlanView()
            } label: {
                PrimaryActionTile(
                    title: "Build My Day",
                    subtitle: "Plan with time blocks",
                    systemImage: "calendar",
                    accent: AppColors.sky,
                    background: AppColors.skySoft
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HomeGreetingHeader: View {
    var greeting: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(greeting)
                        .font(AppTypography.display(size: 27))
                        .foregroundStyle(AppColors.navy)
                    Image(systemName: "moon.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColors.lavender.opacity(0.68))
                        .offset(y: 1)
                }

                Text("Gentle Day")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.lavenderDeep)
            }

            Spacer()

            GentleLogoMark(size: 42)
        }
    }
}

private struct TodayFocusCard: View {
    var entries: [HomeFocusEntry]

    var body: some View {
        SoftCard(innerPadding: 17) {
            VStack(alignment: .leading, spacing: 15) {
                SectionTitleView(title: "Today's Focus", trailingTitle: "Edit", trailingAction: {})

                VStack(spacing: 12) {
                    ForEach(entries.prefix(3)) { entry in
                        HStack(spacing: 11) {
                            Image(systemName: "circle")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(AppColors.sage)

                            Text(entry.title)
                                .font(AppTypography.bodyEmphasis)
                                .foregroundStyle(AppColors.slate)
                                .lineLimit(1)

                            Spacer()

                            CategoryIconBadge(category: entry.category, size: 27)
                        }
                    }
                }
            }
        }
    }
}

private struct NextBlockSummaryCard: View {
    var block: ScheduleBlock?

    var body: some View {
        NavigationLink {
            TodayScheduleView()
        } label: {
            SoftCard(innerPadding: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "clock")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(AppColors.lavenderDeep)
                        .frame(width: 48, height: 48)
                        .background(AppColors.lavenderSoft)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Block")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.mutedText)

                        if let block {
                            Text(DateFormatting.timeRange(start: block.startTime, end: block.endTime))
                                .font(AppTypography.callout.weight(.semibold))
                                .foregroundStyle(AppColors.navy)
                            Text(block.title)
                                .font(AppTypography.cardTitle)
                                .foregroundStyle(AppColors.navy)
                                .lineLimit(1)
                        } else {
                            Text("No block is waiting")
                                .font(AppTypography.cardTitle)
                                .foregroundStyle(AppColors.navy)
                            Text("Build a day whenever you're ready.")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.mutedText)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.faintText)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .modelContainer(PersistenceController.makeModelContainer())
}
