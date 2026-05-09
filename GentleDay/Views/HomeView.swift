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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Resting hours"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xxl) {
                header
                actionGrid
                focusSection
                nextBlockSection
                winsRow
                footer
            }
            .padding(GentleTheme.Spacing.screenHorizontal)
            .gentleBottomSafePad()
        }
        .gentleBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.sm) {
            Text(greeting)
                .font(GentleTheme.Typography.displayLarge)
                .foregroundStyle(GentleTheme.textPrimary)
            Text("Let's plan a gentle day.")
                .font(GentleTheme.Typography.body)
                .foregroundStyle(GentleTheme.textSecondary)
        }
    }

    private var actionGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: GentleTheme.Spacing.md)],
            spacing: GentleTheme.Spacing.md
        ) {
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
                    subtitle: "Hide the noise. Restart small.",
                    systemImage: "wind",
                    tint: GentleTheme.sky
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                BuildPlanView()
            } label: {
                GentleActionCard(
                    title: "Build My Day",
                    subtitle: "A flexible plan with buffers.",
                    systemImage: "wand.and.stars",
                    tint: GentleTheme.butter
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var focusSection: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            GentleSectionHeader(title: "Today's Focus", subtitle: "Up to three things. The list can stay small.")
            if focusItems.isEmpty {
                GentleEmptyState(
                    title: "Nothing needs your attention yet",
                    message: "Capture something when it shows up, or build a gentle plan.",
                    systemImage: "leaf.fill"
                )
            } else {
                VStack(spacing: GentleTheme.Spacing.sm) {
                    ForEach(focusItems, id: \.self) { item in
                        HStack(spacing: GentleTheme.Spacing.md) {
                            Image(systemName: "circle.fill")
                                .font(.caption2)
                                .foregroundStyle(GentleTheme.primary)
                                .accessibilityHidden(true)
                            Text(item)
                                .font(GentleTheme.Typography.bodyEmphasized)
                                .foregroundStyle(GentleTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(.horizontal, GentleTheme.Spacing.lg)
                        .padding(.vertical, GentleTheme.Spacing.md)
                        .background(GentleTheme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous)
                                .stroke(GentleTheme.outline, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var nextBlockSection: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            GentleSectionHeader(title: "Next Block", subtitle: "Flexible, movable, and not a test.")
            if let nextBlock {
                VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
                    HStack(alignment: .top, spacing: GentleTheme.Spacing.md) {
                        GentleIconBadge(
                            systemName: GentleTaskCard.icon(for: nextBlock.category),
                            tint: GentleTheme.color(for: nextBlock.category),
                            size: .medium
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nextBlock.flexibleWindowLabel)
                                .font(GentleTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(GentleTheme.textSecondary)
                                .textCase(.uppercase)
                            Text(nextBlock.title)
                                .font(GentleTheme.Typography.headline)
                                .foregroundStyle(GentleTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(DateFormatting.timeRange(start: nextBlock.startTime, end: nextBlock.endTime))
                                .font(GentleTheme.Typography.caption)
                                .foregroundStyle(GentleTheme.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }

                    NavigationLink {
                        TodayScheduleView()
                    } label: {
                        Label("Open Today", systemImage: "arrow.right.circle.fill")
                            .font(GentleTheme.Typography.headline)
                            .foregroundStyle(GentleTheme.primary)
                    }
                    .buttonStyle(.plain)
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
        }
    }

    private var winsRow: some View {
        HStack(spacing: GentleTheme.Spacing.md) {
            GentleIconBadge(systemName: "checkmark.seal.fill", tint: GentleTheme.sage, size: .small)
            Text("\(completedTodayCount) gentle win\(completedTodayCount == 1 ? "" : "s") today.")
                .font(GentleTheme.Typography.subheadline.weight(.medium))
                .foregroundStyle(GentleTheme.textPrimary)
            Spacer()
        }
        .padding(GentleTheme.Spacing.cardPadding)
        .background(GentleTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous)
                .stroke(GentleTheme.outline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous))
    }

    private var footer: some View {
        Text("Be kind. Small steps count.")
            .font(GentleTheme.Typography.compassionate)
            .foregroundStyle(GentleTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, GentleTheme.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(PersistenceController.makeModelContainer())
}
