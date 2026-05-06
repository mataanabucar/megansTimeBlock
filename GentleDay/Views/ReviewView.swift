import SwiftData
import SwiftUI

struct ReviewView: View {
    @Environment(\.gentleActiveTab) private var gentleActiveTab
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
        GentleScrollView(spacing: 19) {
            GentlePageHeader(
                title: "Review",
                subtitle: "Today • \(DateFormatting.shortDate.string(from: Date()))",
                trailingSystemImage: "line.3.horizontal",
                trailingAction: {}
            )

            HStack(spacing: 10) {
                ReviewMetricCard(title: "Completed", count: completed.count, tint: AppColors.sage)
                ReviewMetricCard(title: "Moved", count: moved.count, tint: AppColors.lavender)
                ReviewMetricCard(title: "Unfinished", count: unfinished.count, tint: AppColors.butter)
            }

            ReviewSupportCard(
                message: reviewMessage,
                onCarry: carryUnfinishedToTomorrow,
                onInbox: returnUnfinishedToInbox,
                onDrop: dropUnfinishedForNow,
                onMinimumDay: buildTomorrowMinimumDay
            )

            if todayBlocks.isEmpty {
                GentleEmptyState(
                    title: "No blocks to review",
                    message: "A quiet day can still count.",
                    systemImage: "moon"
                )
            } else {
                ReviewStatusSection(title: "Completed", blocks: completed, emptyMessage: "No completed blocks yet.")
                ReviewStatusSection(title: "Moved", blocks: moved, emptyMessage: "Nothing moved today.")
                ReviewStatusSection(title: "Unfinished", blocks: unfinished, emptyMessage: "Nothing unfinished.")
            }
        }
        .gentleBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            gentleActiveTab?.wrappedValue = .review
        }
    }

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

private struct ReviewMetricCard: View {
    var title: String
    var count: Int
    var tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Text("\(count)")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(AppColors.navy)

            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(AppColors.softBorder.opacity(0.42), lineWidth: 0.7)
        }
    }
}

private struct ReviewSupportCard: View {
    var message: String
    var onCarry: () -> Void
    var onInbox: () -> Void
    var onDrop: () -> Void
    var onMinimumDay: () -> Void

    var body: some View {
        SoftCard(background: AppColors.lavenderMist, stroke: AppColors.lavender.opacity(0.18)) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(AppColors.sage)
                        .frame(width: 38, height: 38)
                        .background(AppColors.card.opacity(0.78))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Gentle summary")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundStyle(AppColors.navy)
                        Text(message)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.mutedText)
                            .lineSpacing(2)
                    }
                }

                VStack(spacing: 9) {
                    ReviewActionButton(title: "Carry unfinished to tomorrow", systemImage: "arrow.right", action: onCarry)
                    ReviewActionButton(title: "Return unfinished to Inbox", systemImage: "tray", action: onInbox)
                    ReviewActionButton(title: "Drop unfinished for now", systemImage: "hand.raised", action: onDrop)
                    ReviewActionButton(title: "Build tomorrow's minimum day", systemImage: "sparkles", action: onMinimumDay)
                }
            }
        }
    }
}

private struct ReviewActionButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .foregroundStyle(AppColors.slate)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(AppColors.card.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ReviewStatusSection: View {
    var title: String
    var blocks: [ScheduleBlock]
    var emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.slate)

            if blocks.isEmpty {
                Text(emptyMessage)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.mutedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
                    .background(AppColors.card.opacity(0.70))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
            } else {
                VStack(spacing: 9) {
                    ForEach(blocks.sorted { $0.startTime < $1.startTime }) { block in
                        HStack(spacing: 12) {
                            CategoryIconBadge(category: block.category, size: 34)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(block.title)
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundStyle(AppColors.navy)
                                Text(block.status.title)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.mutedText)
                            }

                            Spacer()

                            Image(systemName: icon(for: block.status))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(tint(for: block.status))
                        }
                        .padding(14)
                        .background(AppColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                                .stroke(AppColors.softBorder.opacity(0.48), lineWidth: 0.7)
                        }
                    }
                }
            }
        }
    }

    private func icon(for status: BlockStatus) -> String {
        switch status {
        case .done: "checkmark"
        case .moved, .snoozed: "arrow.right"
        case .skipped: "minus"
        case .planned, .inProgress: "circle"
        }
    }

    private func tint(for status: BlockStatus) -> Color {
        switch status {
        case .done: AppColors.success
        case .moved, .snoozed: AppColors.lavender
        case .skipped: AppColors.butter
        case .planned, .inProgress: AppColors.faintText
        }
    }
}
