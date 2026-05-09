import SwiftData
import SwiftUI

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var blocks: [ScheduleBlock]
    @Query private var tasks: [TaskItem]
    @Query private var preferences: [UserPlanningPreferences]
    @State private var reviewMessage = "Nothing needs to be perfect to be useful."

    private var todayBlocks: [ScheduleBlock] {
        blocks.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    private var completed: [ScheduleBlock] {
        todayBlocks.filter { $0.status == .done }
    }

    private var moved: [ScheduleBlock] {
        todayBlocks.filter { $0.status == .moved || $0.status == .snoozed || $0.status == .skipped }
    }

    private var unfinished: [ScheduleBlock] {
        todayBlocks.filter { $0.status == .planned || $0.status == .inProgress }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xl) {
                GentleSectionHeader(
                    title: "Gentle Review",
                    subtitle: "Notice what happened and choose what stays."
                )

                metricsRow
                actionsCard

                if todayBlocks.isEmpty {
                    GentleEmptyState(
                        title: "No blocks to review",
                        message: "A quiet day can still count.",
                        systemImage: "moon"
                    )
                } else {
                    blockSummaryList
                }
            }
            .padding(GentleTheme.Spacing.screenHorizontal)
            .gentleBottomSafePad()
        }
        .gentleBackground()
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metricsRow: some View {
        HStack(spacing: GentleTheme.Spacing.md) {
            ReviewMetric(title: "Completed", count: completed.count, color: GentleTheme.sage)
            ReviewMetric(title: "Moved", count: moved.count, color: GentleTheme.sky)
            ReviewMetric(title: "Unfinished", count: unfinished.count, color: GentleTheme.butter)
        }
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            Text(reviewMessage)
                .font(GentleTheme.Typography.bodyEmphasized)
                .foregroundStyle(GentleTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: GentleTheme.Spacing.sm) {
                GentleButton(
                    title: "Carry unfinished to tomorrow",
                    systemImage: "arrow.right.circle.fill",
                    role: .secondary,
                    action: carryUnfinishedToTomorrow
                )
                GentleButton(
                    title: "Return unfinished to Inbox",
                    systemImage: "tray.and.arrow.up.fill",
                    role: .secondary,
                    action: returnUnfinishedToInbox
                )
                GentleButton(
                    title: "Drop unfinished for now",
                    systemImage: "leaf.arrow.circlepath",
                    role: .secondary,
                    action: dropUnfinishedForNow
                )
                GentleButton(
                    title: "Build tomorrow's minimum day",
                    systemImage: "moon.stars.fill",
                    role: .primary,
                    action: buildTomorrowMinimumDay
                )
            }
        }
        .gentleCardStyle()
    }

    private var blockSummaryList: some View {
        VStack(spacing: GentleTheme.Spacing.md) {
            ForEach(todayBlocks.sorted { $0.startTime < $1.startTime }) { block in
                HStack(spacing: GentleTheme.Spacing.md) {
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
                        Text(block.status.title)
                            .font(GentleTheme.Typography.caption)
                            .foregroundStyle(GentleTheme.textSecondary)
                    }
                    Spacer()
                }
                .gentleCardStyle()
            }
        }
    }

    // MARK: - Actions

    private func carryUnfinishedToTomorrow() {
        unfinished.forEach {
            TaskActionService.moveBlockToTomorrow($0, tasks: tasks, context: modelContext)
        }
        saveReview(note: "Unfinished items were carried to tomorrow.")
        reviewMessage = "Carried forward gently."
    }

    private func returnUnfinishedToInbox() {
        for block in unfinished {
            if let task = TaskActionService.matchingTask(for: block, in: tasks) {
                task.status = .inbox
            }
            ReminderService.shared.cancelReminder(for: block)
            modelContext.delete(block)
        }
        try? modelContext.save()
        saveReview(note: "Unfinished items returned to the inbox.")
        reviewMessage = "Returned to the inbox."
    }

    private func dropUnfinishedForNow() {
        unfinished.forEach {
            TaskActionService.skipWithoutGuilt($0, tasks: tasks, context: modelContext)
        }
        saveReview(note: "Unfinished items were dropped for now.")
        reviewMessage = "Dropped for now."
    }

    private func buildTomorrowMinimumDay() {
        guard let preference = preferences.first else { return }
        let service = MockAIScheduleService()
        Task {
            let response = try? await service.generatePlan(
                tasks: tasks,
                existingScheduleBlocks: blocks,
                preferences: preference,
                scheduleRange: .tomorrow,
                planningStyle: .minimumDay
            )
            await MainActor.run {
                guard let response else { return }
                for plannedBlock in response.proposedScheduleBlocks {
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
                    }
                }
                try? modelContext.save()
                saveReview(note: "Tomorrow's minimum day was built.")
                reviewMessage = response.friendlySummary
            }
        }
    }

    private func saveReview(note: String) {
        let entry = ReviewEntry(
            completedCount: completed.count,
            movedCount: moved.count,
            unfinishedCount: unfinished.count,
            note: note
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }
}

private struct ReviewMetric: View {
    var title: String
    var count: Int
    var color: Color

    var body: some View {
        VStack(spacing: GentleTheme.Spacing.sm) {
            Text("\(count)")
                .font(GentleTheme.Typography.displayMedium)
                .foregroundStyle(GentleTheme.textPrimary)
            Text(title)
                .font(GentleTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(GentleTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GentleTheme.Spacing.lg)
        .background(color.opacity(0.30))
        .overlay {
            RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous)
                .stroke(color.opacity(0.5), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        ReviewView()
    }
    .modelContainer(PersistenceController.makeModelContainer())
}
