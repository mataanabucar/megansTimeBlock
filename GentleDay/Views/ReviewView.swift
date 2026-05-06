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
            VStack(alignment: .leading, spacing: 18) {
                GentleSectionHeader(
                    title: "Gentle Review",
                    subtitle: "Notice what happened and choose what stays."
                )

                HStack(spacing: 12) {
                    ReviewMetric(title: "Completed", count: completed.count, color: GentleTheme.sage)
                    ReviewMetric(title: "Moved", count: moved.count, color: GentleTheme.sky)
                    ReviewMetric(title: "Unfinished", count: unfinished.count, color: GentleTheme.butter)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(reviewMessage)
                        .font(.headline)
                        .foregroundStyle(GentleTheme.ink)

                    Button("Carry unfinished to tomorrow") {
                        carryUnfinishedToTomorrow()
                    }
                    Button("Return unfinished to Inbox") {
                        returnUnfinishedToInbox()
                    }
                    Button("Drop unfinished for now") {
                        dropUnfinishedForNow()
                    }
                    Button("Build tomorrow's minimum day") {
                        buildTomorrowMinimumDay()
                    }
                }
                .buttonStyle(.bordered)
                .tint(GentleTheme.sage)
                .gentleCardStyle()

                if todayBlocks.isEmpty {
                    GentleEmptyState(
                        title: "No blocks to review",
                        message: "A quiet day can still count.",
                        systemImage: "moon"
                    )
                } else {
                    ForEach(todayBlocks.sorted { $0.startTime < $1.startTime }) { block in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(block.title)
                                    .font(.headline)
                                Text(block.status.title)
                                    .font(.caption)
                                    .foregroundStyle(GentleTheme.mutedInk)
                            }
                            Spacer()
                        }
                        .gentleCardStyle()
                    }
                }
            }
            .padding(20)
        }
        .gentleBackground()
        .navigationTitle("Review")
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

private struct ReviewMetric: View {
    var title: String
    var count: Int
    var color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.title.weight(.bold))
                .foregroundStyle(GentleTheme.ink)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(GentleTheme.mutedInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(color.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

