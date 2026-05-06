import SwiftData
import SwiftUI

struct TodayScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var blocks: [ScheduleBlock]
    @Query private var tasks: [TaskItem]
    @State private var shrinkBlock: ScheduleBlock?

    private var todayBlocks: [ScheduleBlock] {
        blocks
            .filter { Calendar.current.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GentleSectionHeader(
                    title: "Today Schedule",
                    subtitle: "Flexible blocks, not a rigid calendar."
                )

                if todayBlocks.isEmpty {
                    GentleEmptyState(
                        title: "No blocks for today",
                        message: "Build a plan, schedule from the inbox, or let today stay open.",
                        systemImage: "calendar"
                    )
                } else {
                    ForEach(todayBlocks) { block in
                        ScheduleBlockCard(
                            block: block,
                            task: TaskActionService.matchingTask(for: block, in: tasks),
                            onDone: { TaskActionService.markBlockDone(block, tasks: tasks, context: modelContext) },
                            onSnooze: { TaskActionService.snoozeBlock(block, minutes: 15, tasks: tasks, context: modelContext) },
                            onShrink: { shrinkBlock = block },
                            onMoveLater: { TaskActionService.moveBlockLater(block, tasks: tasks, context: modelContext) },
                            onTomorrow: { TaskActionService.moveBlockToTomorrow(block, tasks: tasks, context: modelContext) },
                            onSkip: { TaskActionService.skipWithoutGuilt(block, tasks: tasks, context: modelContext) }
                        )
                    }
                }
            }
            .padding(20)
        }
        .gentleBackground()
        .navigationTitle("Today")
        .sheet(item: $shrinkBlock) { block in
            ShrinkOptionsSheet(block: block, tasks: tasks)
        }
    }
}

private struct ScheduleBlockCard: View {
    var block: ScheduleBlock
    var task: TaskItem?
    var onDone: () -> Void
    var onSnooze: () -> Void
    var onShrink: () -> Void
    var onMoveLater: () -> Void
    var onTomorrow: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(GentleTheme.color(for: block.category))
                    .frame(width: 8)

                VStack(alignment: .leading, spacing: 7) {
                    Text(block.flexibleWindowLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GentleTheme.mutedInk)
                    Text(block.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(GentleTheme.ink)
                    Text("\(DateFormatting.timeRange(start: block.startTime, end: block.endTime)) · \(block.durationMinutes) min")
                        .font(.subheadline)
                        .foregroundStyle(GentleTheme.mutedInk)
                    if let task, !task.suggestedTinyStep.isEmpty {
                        Text("One small step: \(task.suggestedTinyStep)")
                            .font(.subheadline)
                            .foregroundStyle(GentleTheme.ink)
                    }
                }
                Spacer()
            }

            GentleMetadataRow(items: [block.category.title, block.status.title, block.reminderStyle.title])

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                Button("Done", action: onDone)
                Button("Snooze", action: onSnooze)
                Button("Shrink", action: onShrink)
                Button("Move Later", action: onMoveLater)
                Button("Tomorrow", action: onTomorrow)
                Button("Skip Without Guilt", action: onSkip)
            }
            .buttonStyle(.bordered)
            .tint(GentleTheme.sage)
        }
        .gentleCardStyle()
    }
}

private struct ShrinkOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var block: ScheduleBlock
    var tasks: [TaskItem]

    private var options: [String] {
        TaskActionService.matchingTask(for: block, in: tasks)?.shrinkOptions ?? [
            "Do the first visible step, 3 min",
            "Set a 10-minute timer",
            "Prepare what you need, 5 min"
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Smaller options") {
                    ForEach(options, id: \.self) { option in
                        Button(option) {
                            TaskActionService.applyShrinkOption(option, to: block, tasks: tasks, context: modelContext)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Shrink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

