import SwiftData
import SwiftUI

struct TodayScheduleView: View {
    @Environment(\.gentleActiveTab) private var gentleActiveTab
    @Environment(\.modelContext) private var modelContext
    @Query private var blocks: [ScheduleBlock]
    @Query private var tasks: [TaskItem]
    @State private var shrinkBlock: ScheduleBlock?
    @State private var editingBlock: ScheduleBlock?
    @State private var blockPendingDelete: ScheduleBlock?
    @State private var selectedBlockID: UUID?

    private var todayBlocks: [ScheduleBlock] {
        blocks
            .filter { Calendar.current.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    private var selectedBlock: ScheduleBlock? {
        if let selectedBlockID,
           let block = todayBlocks.first(where: { $0.id == selectedBlockID }) {
            return block
        }
        return todayBlocks.first { $0.status == .inProgress }
            ?? todayBlocks.dropFirst().first
            ?? todayBlocks.first
    }

    private var todayBlockIDs: [UUID] {
        todayBlocks.map(\.id)
    }

    var body: some View {
        GentleScrollView(spacing: 19) {
            GentlePageHeader(
                title: "Today",
                subtitle: "Flexible blocks, less pressure.",
                trailingSystemImage: "slider.horizontal.3",
                trailingAction: {}
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Your day at a glance")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.slate)

                HStack(spacing: 10) {
                    DaySummaryCard(
                        title: "Minimum Day",
                        subtitle: "\(minimumCount) essentials",
                        systemImage: "leaf.fill",
                        tint: AppColors.mint
                    )

                    DaySummaryCard(
                        title: "Ideal Plan",
                        subtitle: "\(max(todayBlocks.count, minimumCount)) items",
                        systemImage: "sun.max.fill",
                        tint: AppColors.butter
                    )
                }
            }

            if todayBlocks.isEmpty {
                GentleEmptyState(
                    title: "No blocks for today",
                    message: "Build a plan, schedule from the inbox, or let today stay open.",
                    systemImage: "calendar"
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Blocks")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.slate)

                    VStack(spacing: 12) {
                        ForEach(todayBlocks) { block in
                            ScheduleBlockCard(
                                block: block,
                                task: TaskActionService.matchingTask(for: block, in: tasks),
                                isSelected: block.id == selectedBlock?.id,
                                onSelect: { selectedBlockID = block.id },
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
            }
        }
        .gentleBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            gentleActiveTab?.wrappedValue = .plan
            ensureSelectedBlock()
        }
        .onChange(of: todayBlockIDs) { _, _ in
            ensureSelectedBlock()
        }
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

    private var minimumCount: Int {
        max(1, min(3, todayBlocks.filter { $0.status != .done && $0.status != .skipped }.count))
    }

    private func ensureSelectedBlock() {
        guard !todayBlocks.isEmpty else {
            selectedBlockID = nil
            return
        }

        if let selectedBlockID,
           todayBlocks.contains(where: { $0.id == selectedBlockID }) {
            return
        }

        selectedBlockID = selectedBlock?.id
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

private struct DaySummaryCard: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color

    var body: some View {
        SoftCard(background: AppColors.card, cornerRadius: DesignTokens.Radius.lg, innerPadding: 13) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 31, height: 31)
                    .background(tint.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.navy)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.mutedText)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct ScheduleBlockCard: View {
    var block: ScheduleBlock
    var task: TaskItem?
    var isSelected: Bool
    var onSelect: () -> Void
    var onEdit: () -> Void
    var onDone: () -> Void
    var onSnooze: () -> Void
    var onShrink: () -> Void
    var onMoveLater: () -> Void
    var onTomorrow: () -> Void
    var onSkip: () -> Void
    var onDelete: () -> Void

    var body: some View {
        SoftCard(
            background: isSelected ? AppColors.lavenderMist : AppColors.card,
            stroke: isSelected ? AppColors.lavender.opacity(0.72) : AppColors.softBorder.opacity(0.65),
            cornerRadius: DesignTokens.Radius.xl,
            innerPadding: 16
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 13) {
                    CategoryIconBadge(category: block.category, size: 43)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Text(block.flexibleWindowLabel)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.slate)
                            Text(DateFormatting.timeRange(start: block.startTime, end: block.endTime))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.mutedText)
                        }

                        Text(block.title)
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(AppColors.navy)
                            .fixedSize(horizontal: false, vertical: true)

                        if isSelected, let task, !task.suggestedTinyStep.isEmpty {
                            Text(task.suggestedTinyStep)
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.mutedText)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.faintText)
                        .padding(.top, 5)
                }

                if isSelected {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 9),
                            GridItem(.flexible(), spacing: 9)
                        ],
                        spacing: 9
                    ) {
                        BlockActionButton(title: "Done", systemImage: "checkmark", background: AppColors.sageSoft, action: onDone)
                        BlockActionButton(title: "Shrink", systemImage: "arrow.down.right.and.arrow.up.left", background: AppColors.lavenderSoft, action: onShrink)
                        BlockActionButton(title: "Move Later", systemImage: "calendar", background: AppColors.lavenderSoft, action: onMoveLater)
                        BlockActionButton(title: "Tomorrow", systemImage: "sun.max", background: AppColors.peachSoft, action: onTomorrow)
                    }
                }
            }
        }
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Edit", action: onEdit)
            Button("Snooze 15 min", action: onSnooze)
            Button("Skip without guilt", action: onSkip)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }
}

private struct BlockActionButton: View {
    var title: String
    var systemImage: String
    var background: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.slate)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
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
