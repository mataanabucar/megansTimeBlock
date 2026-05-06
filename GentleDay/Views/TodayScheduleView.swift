import SwiftData
import SwiftUI

struct TodayScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var blocks: [ScheduleBlock]
    @Query private var tasks: [TaskItem]
    @State private var shrinkBlock: ScheduleBlock?
    @State private var editingBlock: ScheduleBlock?
    @State private var blockPendingDelete: ScheduleBlock?

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
                            onEdit: { editingBlock = block },
                            onDone: { TaskActionService.markBlockDone(block, tasks: tasks, context: modelContext) },
                            onSnooze: { TaskActionService.snoozeBlock(block, minutes: 15, tasks: tasks, context: modelContext) },
                            onShrink: { shrinkBlock = block },
                            onMoveLater: { TaskActionService.moveBlockLater(block, tasks: tasks, context: modelContext) },
                            onTomorrow: { TaskActionService.moveBlockToTomorrow(block, tasks: tasks, context: modelContext) },
                            onSkip: { TaskActionService.skipWithoutGuilt(block, tasks: tasks, context: modelContext) },
                            onDelete: { blockPendingDelete = block }
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
        .sheet(item: $editingBlock) { block in
            NavigationStack {
                ScheduleBlockEditView(block: block)
            }
        }
        .confirmationDialog(
            "Delete this scheduled block?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Delete Block", role: .destructive) {
                if let blockPendingDelete {
                    delete(blockPendingDelete)
                }
                blockPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                blockPendingDelete = nil
            }
        } message: {
            Text("This removes the scheduled block. The original task stays in your app unless you delete it from the inbox or editor.")
        }
    }

    private func delete(_ block: ScheduleBlock) {
        ReminderService.shared.cancelReminder(for: block)
        modelContext.delete(block)
        try? modelContext.save()
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { blockPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    blockPendingDelete = nil
                }
            }
        )
    }
}

private struct ScheduleBlockCard: View {
    var block: ScheduleBlock
    var task: TaskItem?
    var onEdit: () -> Void
    var onDone: () -> Void
    var onSnooze: () -> Void
    var onShrink: () -> Void
    var onMoveLater: () -> Void
    var onTomorrow: () -> Void
    var onSkip: () -> Void
    var onDelete: () -> Void

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
                Button("Edit", action: onEdit)
                Button("Done", action: onDone)
                Button("Snooze", action: onSnooze)
                Button("Shrink", action: onShrink)
                Button("Move Later", action: onMoveLater)
                Button("Tomorrow", action: onTomorrow)
                Button("Skip Without Guilt", action: onSkip)
                Button(role: .destructive, action: onDelete) {
                    Text("Delete")
                }
            }
            .buttonStyle(.bordered)
            .tint(GentleTheme.sage)
        }
        .gentleCardStyle()
    }
}

private struct ScheduleBlockEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var block: ScheduleBlock
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Block") {
                TextField("Title", text: $block.title)
                Picker("Category", selection: categoryBinding) {
                    ForEach(TaskCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                Picker("Status", selection: statusBinding) {
                    ForEach(BlockStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
            }

            Section("Time") {
                DatePicker("Starts", selection: startTimeBinding, displayedComponents: [.date, .hourAndMinute])
                Stepper("Duration: \(block.durationMinutes) min", value: durationBinding, in: 5...240, step: 5)
            }

            Section("Reminder") {
                Picker("Reminder", selection: reminderStyleBinding) {
                    ForEach(ReminderStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                Toggle("Locked", isOn: $block.isLocked)
            }

            Section("Why this block exists") {
                TextField("Reason", text: $block.aiReason, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                Button("Delete Block", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("Edit Block")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    block.touch()
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .confirmationDialog(
            "Delete this scheduled block?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Block", role: .destructive) {
                ReminderService.shared.cancelReminder(for: block)
                modelContext.delete(block)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the scheduled block, but not the original task.")
        }
    }

    private var categoryBinding: Binding<TaskCategory> {
        Binding(
            get: { block.category },
            set: { block.category = $0 }
        )
    }

    private var statusBinding: Binding<BlockStatus> {
        Binding(
            get: { block.status },
            set: { block.status = $0 }
        )
    }

    private var reminderStyleBinding: Binding<ReminderStyle> {
        Binding(
            get: { block.reminderStyle },
            set: { block.reminderStyle = $0 }
        )
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { block.startTime },
            set: { newStart in
                let duration = block.durationMinutes
                block.startTime = newStart
                block.endTime = Calendar.current.date(byAdding: .minute, value: duration, to: newStart) ?? newStart
                block.flexibleWindowLabel = DateFormatting.flexibleWindowLabel(for: newStart)
                block.touch()
            }
        )
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { block.durationMinutes },
            set: { block.resize(toMinutes: $0) }
        )
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
