import SwiftData
import SwiftUI

struct BuildPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var blocks: [ScheduleBlock]
    @Query private var preferences: [UserPlanningPreferences]
    @State private var viewModel = BuildPlanViewModel()
    @State private var didApplyInitial = false

    /// Optional pre-selected range — used when the screen is pushed from a
    /// flow like "I'm Overwhelmed → Plan Tomorrow".
    var initialRange: ScheduleRange? = nil
    /// Optional pre-selected style.
    var initialStyle: PlanningStyle? = nil

    private var openTaskCount: Int {
        tasks.filter { [.inbox, .shrunk, .snoozed, .moved].contains($0.status) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xl) {
                header
                rangeCard
                styleSection
                availableTimeCard
                inboxCountCard
                if let response = viewModel.response {
                    PlanResponseView(response: response)
                }
                if let errorMessage = viewModel.errorMessage {
                    errorCard(errorMessage)
                }
            }
            .padding(GentleTheme.Spacing.screenHorizontal)
        }
        .gentleBackground()
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            generateBar
        }
        .onAppear {
            guard !didApplyInitial else { return }
            if let initialRange { viewModel.selectedRange = initialRange }
            if let initialStyle { viewModel.selectedStyle = initialStyle }
            didApplyInitial = true
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.sm) {
            Text("Build My Day")
                .font(GentleTheme.Typography.displayLarge)
                .foregroundStyle(GentleTheme.textPrimary)
            Text("Create a gentle plan that fits your day and energy.")
                .font(GentleTheme.Typography.body)
                .foregroundStyle(GentleTheme.textSecondary)
        }
    }

    private var rangeCard: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            Text("Plan range")
                .font(GentleTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(GentleTheme.textSecondary)
                .textCase(.uppercase)
            Picker("Range", selection: $viewModel.selectedRange) {
                ForEach(ScheduleRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
        .gentleCardStyle()
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            GentleSectionHeader(
                title: "Planning style",
                subtitle: viewModel.selectedStyle.friendlyDescription
            )

            VStack(spacing: GentleTheme.Spacing.md) {
                ForEach(PlanningStyle.allCases) { style in
                    GentleModeCard(
                        title: style.title,
                        subtitle: style.friendlyDescription,
                        systemImage: icon(for: style),
                        tint: tint(for: style),
                        isSelected: viewModel.selectedStyle == style,
                        action: { viewModel.selectedStyle = style }
                    )
                }
            }
        }
    }

    private var availableTimeCard: some View {
        HStack(spacing: GentleTheme.Spacing.md) {
            GentleIconBadge(systemName: "clock.fill", tint: GentleTheme.sky, size: .medium)
            VStack(alignment: .leading, spacing: 2) {
                Text(availableTimeText)
                    .font(GentleTheme.Typography.headline)
                    .foregroundStyle(GentleTheme.textPrimary)
                Text(availabilityCaption)
                    .font(GentleTheme.Typography.caption)
                    .foregroundStyle(GentleTheme.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gentleCardStyle()
    }

    private var inboxCountCard: some View {
        HStack(spacing: GentleTheme.Spacing.md) {
            GentleIconBadge(systemName: "tray.full.fill", tint: GentleTheme.peach, size: .medium)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(openTaskCount) inbox item\(openTaskCount == 1 ? "" : "s") available")
                    .font(GentleTheme.Typography.headline)
                    .foregroundStyle(GentleTheme.textPrimary)
                Text("Extra items stay in the inbox instead of being forced into the day.")
                    .font(GentleTheme.Typography.caption)
                    .foregroundStyle(GentleTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gentleCardStyle()
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: GentleTheme.Spacing.md) {
            GentleIconBadge(systemName: "exclamationmark.triangle.fill", tint: GentleTheme.dangerSoft, size: .small)
            Text(message)
                .font(GentleTheme.Typography.subheadline)
                .foregroundStyle(GentleTheme.textPrimary)
            Spacer()
        }
        .gentleCardStyle()
    }

    private var generateBar: some View {
        VStack(spacing: GentleTheme.Spacing.sm) {
            GentleButton(
                title: viewModel.isGenerating ? "Building..." : "Generate Gentle Plan",
                systemImage: "wand.and.stars",
                role: .primary,
                isLoading: viewModel.isGenerating,
                isEnabled: !viewModel.isGenerating && preferences.first != nil,
                action: generatePlan
            )

            NavigationLink {
                TodayScheduleView()
            } label: {
                Label("Open Today", systemImage: "calendar")
                    .font(GentleTheme.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(GentleTheme.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, GentleTheme.Spacing.screenHorizontal)
        .padding(.top, GentleTheme.Spacing.md)
        .padding(.bottom, GentleTheme.Spacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GentleTheme.outline)
                .frame(height: 1)
        }
    }

    // MARK: - Plan generation

    private func generatePlan() {
        guard let preference = preferences.first else { return }
        Task {
            guard let response = await viewModel.generate(
                tasks: tasks,
                existingScheduleBlocks: blocks,
                preferences: preference
            ) else { return }

            persist(response)
        }
    }

    @MainActor
    private func persist(_ response: AIPlanResponse) {
        for plannedBlock in response.proposedScheduleBlocks {
            let alreadyExists = blocks.contains { existing in
                existing.taskId == plannedBlock.taskId && existing.status != .done && existing.status != .skipped
            }
            guard !alreadyExists else { continue }

            let block = ScheduleBlock(
                id: plannedBlock.id,
                taskId: plannedBlock.taskId,
                title: plannedBlock.title,
                startTime: plannedBlock.startTime,
                endTime: plannedBlock.endTime,
                flexibleWindowLabel: plannedBlock.flexibleWindowLabel,
                category: plannedBlock.category,
                reminderStyle: plannedBlock.reminderStyle,
                aiReason: plannedBlock.aiReason
            )
            modelContext.insert(block)

            if let task = tasks.first(where: { $0.id == plannedBlock.taskId }) {
                task.status = .scheduled
                Task {
                    try? await ReminderService.shared.scheduleReminder(for: block, task: task)
                }
            }
        }

        try? modelContext.save()
    }

    // MARK: - Helpers

    private func icon(for style: PlanningStyle) -> String {
        switch style {
        case .balancedDay: "leaf.fill"
        case .lightDay: "sun.haze.fill"
        case .catchUpDay: "checklist"
        case .errandsDay: "bag.fill"
        case .homeReset: "house.fill"
        case .minimumDay: "moon.stars.fill"
        }
    }

    private func tint(for style: PlanningStyle) -> Color {
        switch style {
        case .balancedDay: GentleTheme.sage
        case .lightDay: GentleTheme.sky
        case .catchUpDay: GentleTheme.peach
        case .errandsDay: GentleTheme.butter
        case .homeReset: GentleTheme.lilac
        case .minimumDay: GentleTheme.rose
        }
    }

    private var availableTimeText: String {
        let mins = availableMinutes
        if mins >= 60 {
            let hours = mins / 60
            let rem = mins % 60
            return rem > 0 ? "About \(hours) hr \(rem) min available" : "About \(hours) hr available"
        }
        return "About \(mins) min available"
    }

    private var availabilityCaption: String {
        switch viewModel.selectedRange {
        case .today: "Estimated time left in today's window."
        case .tomorrow: "Tomorrow's full planning window."
        case .thisWeek: "Roughly 5 weekdays of planning windows."
        }
    }

    private var availableMinutes: Int {
        guard let pref = preferences.first else { return 0 }
        let cal = Calendar.current

        let startMinuteOfDay = minutesIntoDay(pref.defaultWindowStart, calendar: cal)
        let endMinuteOfDay = minutesIntoDay(pref.defaultWindowEnd, calendar: cal)
        let dailyWindow = max(0, endMinuteOfDay - startMinuteOfDay)

        switch viewModel.selectedRange {
        case .today:
            let nowMinute = minutesIntoDay(Date(), calendar: cal)
            return max(0, endMinuteOfDay - nowMinute)
        case .tomorrow:
            return dailyWindow
        case .thisWeek:
            return dailyWindow * 5
        }
    }

    private func minutesIntoDay(_ date: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}

private struct PlanResponseView: View {
    var response: AIPlanResponse

    var body: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            Text(response.friendlySummary)
                .font(GentleTheme.Typography.headline)
                .foregroundStyle(GentleTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(response.warnings) { warning in
                VStack(alignment: .leading, spacing: GentleTheme.Spacing.xs) {
                    Text(warning.message)
                        .font(GentleTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(GentleTheme.textPrimary)
                    if let suggestion = warning.suggestion {
                        Text(suggestion)
                            .font(GentleTheme.Typography.caption)
                            .foregroundStyle(GentleTheme.textSecondary)
                    }
                }
                .padding(GentleTheme.Spacing.md)
                .background(GentleTheme.butter.opacity(0.30))
                .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
            }

            ForEach(response.proposedScheduleBlocks) { block in
                HStack(alignment: .top, spacing: GentleTheme.Spacing.md) {
                    GentleIconBadge(
                        systemName: GentleTaskCard.icon(for: block.category),
                        tint: GentleTheme.color(for: block.category),
                        size: .small
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.title)
                            .font(GentleTheme.Typography.headline)
                            .foregroundStyle(GentleTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(block.flexibleWindowLabel) · \(DateFormatting.timeRange(start: block.startTime, end: block.endTime))")
                            .font(GentleTheme.Typography.caption)
                            .foregroundStyle(GentleTheme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .gentleCardStyle()
    }
}

#Preview {
    NavigationStack {
        BuildPlanView()
    }
    .modelContainer(PersistenceController.makeModelContainer())
}
