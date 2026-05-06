import SwiftData
import SwiftUI

struct HomeView: View {
    @Query private var tasks: [TaskItem]
    @Query private var blocks: [ScheduleBlock]

    private var todayBlocks: [ScheduleBlock] {
        blocks
            .filter { Calendar.current.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    private var nextBlock: ScheduleBlock? {
        todayBlocks.first { [.planned, .inProgress, .snoozed, .moved].contains($0.status) }
    }

    private var focusItems: [String] {
        let blockTitles = todayBlocks
            .filter { $0.status != .done && $0.status != .skipped }
            .prefix(3)
            .map(\.title)

        if !blockTitles.isEmpty {
            return Array(blockTitles)
        }

        return tasks
            .filter { $0.status == .inbox || $0.status == .shrunk }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(3)
            .map(\.title)
    }

    private var completedTodayCount: Int {
        todayBlocks.filter { $0.status == .done }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gentle Day")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(GentleTheme.ink)
                    Text("A calm place to capture, choose, and restart.")
                        .font(.body)
                        .foregroundStyle(GentleTheme.mutedInk)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                    NavigationLink {
                        QuickCaptureView()
                    } label: {
                        GentleActionCard(
                            title: "Capture Something",
                            subtitle: "Save the thought before it drifts away.",
                            systemImage: "plus.bubble.fill",
                            tint: GentleTheme.peach
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        NextActionView()
                    } label: {
                        GentleActionCard(
                            title: "What Should I Do Next?",
                            subtitle: "Get one clear next step.",
                            systemImage: "sparkle.magnifyingglass",
                            tint: GentleTheme.sage
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        OverwhelmedView()
                    } label: {
                        GentleActionCard(
                            title: "I'm Overwhelmed",
                            subtitle: "Hide the noise and restart small.",
                            systemImage: "drop.fill",
                            tint: GentleTheme.sky
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        BuildPlanView()
                    } label: {
                        GentleActionCard(
                            title: "Build My Day",
                            subtitle: "Make a flexible plan with buffers.",
                            systemImage: "calendar.badge.plus",
                            tint: GentleTheme.butter
                        )
                    }
                    .buttonStyle(.plain)
                }

                GentleSectionHeader(title: "Today's Focus", subtitle: "Up to three things. The list can stay small.")
                if focusItems.isEmpty {
                    GentleEmptyState(
                        title: "Nothing needs your attention yet",
                        message: "Capture something when it shows up, or build a gentle plan.",
                        systemImage: "leaf.fill"
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(focusItems, id: \.self) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(GentleTheme.sage)
                                Text(item)
                                    .font(.headline)
                                    .foregroundStyle(GentleTheme.ink)
                                Spacer()
                            }
                            .padding(14)
                            .background(GentleTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }

                GentleSectionHeader(title: "Next Block", subtitle: "Flexible, movable, and not a test.")
                if let nextBlock {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(nextBlock.flexibleWindowLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GentleTheme.mutedInk)
                        Text(nextBlock.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(GentleTheme.ink)
                        Text(DateFormatting.timeRange(start: nextBlock.startTime, end: nextBlock.endTime))
                            .font(.subheadline)
                            .foregroundStyle(GentleTheme.mutedInk)
                        NavigationLink("Open Today Schedule") {
                            TodayScheduleView()
                        }
                        .font(.headline)
                        .foregroundStyle(GentleTheme.sage)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gentleCardStyle()
                } else {
                    GentleEmptyState(
                        title: "No block is waiting",
                        message: "You can build a day or simply keep using the inbox.",
                        systemImage: "calendar"
                    )
                }

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(GentleTheme.sage)
                    Text("\(completedTodayCount) gentle win\(completedTodayCount == 1 ? "" : "s") today.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GentleTheme.ink)
                    Spacer()
                }
                .gentleCardStyle()
            }
            .padding(20)
        }
        .gentleBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HomeView()
        .modelContainer(PersistenceController.makeModelContainer())
}

