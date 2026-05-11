import SwiftData
import SwiftUI

struct TodayScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var blocks: [ScheduleBlock]
    @Query private var tasks: [TaskItem]
    @AppStorage("gentle.today.viewMode") private var viewModeRaw: String = DayViewMode.ideal.rawValue
    @State private var expandedWindows: Set<String> = []
    @State private var shrinkBlock: ScheduleBlock?
    @State private var editingBlock: ScheduleBlock?
    @State private var blockPendingDelete: ScheduleBlock?

    /// The fixed display order for the Today screen's flexible windows.
    /// The fallback "Anytime" bucket catches anything that doesn't match the
    /// known labels.
    private let windowOrder: [String] = ["Morning", "Afternoon", "Evening", "Before bed", "Anytime"]

    private var viewMode: DayViewMode {
        DayViewMode(rawValue: viewModeRaw) ?? .ideal
    }

    private var todayBlocks: [ScheduleBlock] {
        blocks
            .filter { Calendar.current.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }

    private var visibleBlocks: [ScheduleBlock] {
        switch viewMode {
        case .ideal:
            return todayBlocks
        case .minimum:
            return todayBlocks.filter { includeInMinimum($0) }
        }
    }

    private var groupedBlocks: [(window: String, blocks: [ScheduleBlock])] {
        var bucket: [String: [ScheduleBlock]] = [:]
        for block in visibleBlocks {
            let key = windowKey(for: block.flexibleWindowLabel)
            bucket[key, default: []].append(block)
        }
        return windowOrder.compactMap { key in
            guard let list = bucket[key], !list.isEmpty else { return nil }
            return (key, list.sorted { $0.startTime < $1.startTime })
        }
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    private var currentWindowKey: String {
        windowKey(for: DateFormatting.flexibleWindowLabel(for: Date()))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xl) {
                header
                modeCards

                if visibleBlocks.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedBlocks, id: \.window) { group in
                        windowCard(window: group.window, blocks: group.blocks)
                    }
                }
            }
            .padding(GentleTheme.Spacing.screenHorizontal)
            .gentleBottomSafePad()
        }
        .gentleBackground()
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
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
        .onAppear {
            // Auto-expand the current window so users see what's "now" without tapping.
            if expandedWindows.isEmpty {
                expandedWindows.insert(currentWindowKey)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.xs) {
            Text("Today")
                .font(GentleTheme.Typography.displayLarge)
                .foregroundStyle(GentleTheme.textPrimary)
            Text(todayDateString)
                .font(GentleTheme.Typography.body)
                .foregroundStyle(GentleTheme.textSecondary)
        }
    }

    private var modeCards: some View {
        VStack(spacing: GentleTheme.Spacing.md) {
            ForEach(DayViewMode.allCases, id: \.self) { mode in
                GentleModeCard(
                    title: mode.title,
                    subtitle: mode.subtitle,
                    systemImage: mode.systemImage,
                    tint: mode == .minimum ? GentleTheme.sage : GentleTheme.primary,
                    isSelected: viewMode == mode,
                    action: { viewModeRaw = mode.rawValue }
                )
            }
        }
    }

    private var emptyState: some View {
        GentleEmptyState(
            title: viewMode == .minimum ? "Nothing in Minimum Day yet" : "No blocks for today",
            message: viewMode == .minimum
                ? "Mark something Important or Essential, or build a small plan."
                : "Build a plan, schedule from the inbox, or let today stay open.",
            systemImage: "calendar"
        )
    }

    @ViewBuilder
    private func windowCard(window: String, blocks: [ScheduleBlock]) -> some View {
        let isCurrent = window == currentWindowKey
        let isExpanded = expandedWindows.contains(window)
        GentleTimeBlockCard(
            title: window,
            timeRange: timeRange(for: window, blocks: blocks),
            systemImage: icon(for: window),
            tint: tint(for: window),
            taskCount: blocks.count,
            isCurrent: isCurrent,
            isExpanded: isExpanded,
            onToggle: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedWindows.remove(window)
                    } else {
                        expandedWindows.insert(window)
                    }
                }
            }
        ) {
            VStack(spacing: GentleTheme.Spacing.md) {
                ForEach(blocks) { block in
                    ScheduleBlockRow(
                        block: block,
                        task: TaskActionService.matchingTask(for: block, in: tasks),
                        onDone: { TaskActionService.markBlockDone(block, tasks: tasks, context: modelContext) },
                        onShrink: { shrinkBlock = block },
                        onMoveLater: { TaskActionService.moveBlockLater(block, tasks: tasks, context: modelContext) },
                        onTomorrow: { TaskActionService.moveBlockToTomorrow(block, tasks: tasks, context: modelContext) },
                        onSnooze: { TaskActionService.snoozeBlock(block, minutes: 15, tasks: tasks, context: modelContext) },
                        onSkip: { TaskActionService.skipWithoutGuilt(block, tasks: tasks, context: modelContext) },
                        onEdit: { editingBlock = block },
                        onDelete: { blockPendingDelete = block }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func includeInMinimum(_ block: ScheduleBlock) -> Bool {
        let task = TaskActionService.matchingTask(for: block, in: tasks)
        if let priority = task?.priority, priority == .essential || priority == .important {
            return true
        }
        return block.durationMinutes <= 15
    }

    private func windowKey(for label: String) -> String {
        if windowOrder.contains(label) { return label }
        return "Anytime"
    }

    private func icon(for window: String) -> String {
        switch window {
        case "Morning": "sun.max.fill"
        case "Afternoon": "sun.haze.fill"
        case "Evening": "moon.fill"
        case "Before bed": "moon.zzz.fill"
        default: "clock.fill"
        }
    }

    private func tint(for window: String) -> Color {
        switch window {
        case "Morning": GentleTheme.butter
        case "Afternoon": GentleTheme.peach
        case "Evening": GentleTheme.lilac
        case "Before bed": GentleTheme.sky
        default: GentleTheme.sage
        }
    }

    private func timeRange(for window: String, blocks: [ScheduleBlock]) -> String {
        if let first = blocks.min(by: { $0.startTime < $1.startTime }),
           let last = blocks.max(by: { $0.endTime < $1.endTime }) {
            return DateFormatting.timeRange(start: first.startTime, end: last.endTime)
        }
        return defaultRange(for: window)
    }

    private func defaultRange(for window: String) -> String {
        switch window {
        case "Morning": "7am – 12pm"
        case "Afternoon": "12pm – 5pm"
        case "Evening": "5pm – 9pm"
        case "Before bed": "9pm – 11pm"
        default: "Anytime"
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

// MARK: - Schedule block row (inside an expanded window)

private struct ScheduleBlockRow: View {
    let block: ScheduleBlock
    let task: TaskItem?
    var onDone: () -> Void
    var onShrink: () -> Void
    var onMoveLater: () -> Void
    var onTomorrow: () -> Void
    var onSnooze: () -> Void
    var onSkip: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            NavigationLink {
                BlockDetailView(
                    block: block,
                    task: task,
                    onDone: onDone,
                    onShrink: onShrink,
                    onMoveLater: onMoveLater,
                    onTomorrow: onTomorrow,
                    onSnooze: onSnooze,
                    onSkip: onSkip,
                    onEdit: onEdit,
                    onDelete: onDelete
                )
            } label: {
                HStack(alignment: .top, spacing: GentleTheme.Spacing.md) {
                    GentleIconBadge(
                        systemName: GentleTaskCard.icon(for: block.category),
                        tint: GentleTheme.color(for: block.category),
                        size: .medium
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.title)
                            .font(GentleTheme.Typography.headline)
                            .foregroundStyle(GentleTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(DateFormatting.timeRange(start: block.startTime, end: block.endTime)) · \(block.durationMinutes) min")
                            .font(GentleTheme.Typography.caption)
                            .foregroundStyle(GentleTheme.textSecondary)
                        if let task, !task.suggestedTinyStep.isEmpty {
                            Text("Tiny step: \(task.suggestedTinyStep)")
                                .font(GentleTheme.Typography.caption)
                                .foregroundStyle(GentleTheme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .foregroundStyle(GentleTheme.textSecondary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: GentleTheme.Spacing.sm) {
                GentleButton(
                    title: "Done",
                    systemImage: "checkmark.circle.fill",
                    role: .primary,
                    action: onDone
                )
                HStack(spacing: GentleTheme.Spacing.sm) {
                    GentleButton(title: "Shrink", role: .secondary, action: onShrink)
                    GentleButton(title: "Later", role: .secondary, action: onMoveLater)
                    GentleButton(title: "Tomorrow", role: .secondary, action: onTomorrow)
                }
            }

            HStack {
                Spacer()
                Menu {
                    Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                    Button(action: onSnooze) { Label("Snooze 15 min", systemImage: "alarm.fill") }
                    Button(action: onSkip) { Label("Skip without guilt", systemImage: "leaf.arrow.circlepath") }
                    Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                        .font(GentleTheme.Typography.caption.weight(.medium))
                        .foregroundStyle(GentleTheme.textSecondary)
                }
                .accessibilityLabel("More block actions")
            }
        }
        .padding(GentleTheme.Spacing.cardPadding)
        .background(GentleTheme.field)
        .overlay {
            RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous)
                .stroke(GentleTheme.outline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous))
    }
}

// MARK: - Block detail (focused task view for a block)

/// One-block detail screen pushed from a ScheduleBlockRow. Shows a focused
/// task card, prominent actions, an "Add a task to this block" affordance,
/// and a compassionate footer.
private struct BlockDetailView: View {
    let block: ScheduleBlock
    let task: TaskItem?
    var onDone: () -> Void
    var onShrink: () -> Void
    var onMoveLater: () -> Void
    var onTomorrow: () -> Void
    var onSnooze: () -> Void
    var onSkip: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xl) {
                header
                if let task {
                    GentleTaskCard(
                        task: task,
                        layout: .full,
                        primaryAction: GentleTaskAction(
                            title: "Done",
                            systemImage: "checkmark.circle.fill",
                            role: .primary,
                            action: onDone
                        ),
                        secondaryActions: [
                            GentleTaskAction(title: "Shrink", systemImage: "arrow.down.right.and.arrow.up.left", action: onShrink),
                            GentleTaskAction(title: "Later", systemImage: "arrow.right.circle.fill", action: onMoveLater),
                            GentleTaskAction(title: "Tomorrow", systemImage: "moon.fill", action: onTomorrow)
                        ],
                        overflowActions: [
                            GentleTaskAction(title: "Snooze 15 min", systemImage: "alarm.fill", action: onSnooze),
                            GentleTaskAction(title: "Skip without guilt", systemImage: "leaf.arrow.circlepath", action: onSkip),
                            GentleTaskAction(title: "Edit", systemImage: "pencil", action: onEdit),
                            GentleTaskAction(title: "Delete", systemImage: "trash", role: .destructive, action: onDelete)
                        ]
                    )
                } else {
                    blockOnlyCard
                }

                NavigationLink {
                    QuickCaptureView()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add a task to this block")
                    }
                    .font(GentleTheme.Typography.button)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, GentleTheme.Spacing.md + 2)
                    .padding(.horizontal, GentleTheme.Spacing.lg)
                    .foregroundStyle(GentleTheme.primary)
                    .background(GentleTheme.primary.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous)
                            .stroke(GentleTheme.primary.opacity(0.3), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(spacing: GentleTheme.Spacing.xs) {
                    Text("This is enough for now.")
                        .font(GentleTheme.Typography.compassionate)
                        .foregroundStyle(GentleTheme.textPrimary)
                    Text("Small steps still move you forward.")
                        .font(GentleTheme.Typography.compassionate)
                        .foregroundStyle(GentleTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, GentleTheme.Spacing.md)
            }
            .padding(GentleTheme.Spacing.screenHorizontal)
            .gentleBottomSafePad()
        }
        .gentleBackground()
        .navigationTitle(block.flexibleWindowLabel)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.xs) {
            Text(block.flexibleWindowLabel)
                .font(GentleTheme.Typography.title)
                .foregroundStyle(GentleTheme.textPrimary)
            Text("\(DateFormatting.timeRange(start: block.startTime, end: block.endTime)) · 1 task")
                .font(GentleTheme.Typography.subheadline)
                .foregroundStyle(GentleTheme.textSecondary)
        }
    }

    private var blockOnlyCard: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            HStack(alignment: .top, spacing: GentleTheme.Spacing.md) {
                GentleIconBadge(
                    systemName: GentleTaskCard.icon(for: block.category),
                    tint: GentleTheme.color(for: block.category),
                    size: .large
                )
                VStack(alignment: .leading, spacing: GentleTheme.Spacing.sm) {
                    Text(block.title)
                        .font(GentleTheme.Typography.title)
                        .foregroundStyle(GentleTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    GentleMetadataRow(items: [block.category.title, block.status.title, "\(block.durationMinutes) min"])
                }
                Spacer()
            }

            VStack(spacing: GentleTheme.Spacing.sm) {
                GentleButton(title: "Done", systemImage: "checkmark.circle.fill", role: .primary, action: onDone)
                HStack(spacing: GentleTheme.Spacing.sm) {
                    GentleButton(title: "Shrink", role: .secondary, action: onShrink)
                    GentleButton(title: "Later", role: .secondary, action: onMoveLater)
                    GentleButton(title: "Tomorrow", role: .secondary, action: onTomorrow)
                }
            }
        }
        .gentleCardStyle()
    }
}

// MARK: - Schedule block edit form (kept; uses native Form chrome which
// renders fine in light mode)

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
                    ForEach(categoryOptions) { category in
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

    private var categoryOptions: [TaskCategory] {
        TaskCategory.userSelectableCases.contains(block.category)
            ? TaskCategory.userSelectableCases
            : [block.category] + TaskCategory.userSelectableCases
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

#Preview {
    NavigationStack {
        TodayScheduleView()
    }
    .modelContainer(PersistenceController.makeModelContainer())
}
