import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var preferences: [UserPlanningPreferences]
    @AppStorage("gentle.hideNonEssentials") private var hideNonEssentials = false
    @State private var editingTask: TaskItem?
    @State private var taskPendingDelete: TaskItem?

    private var inboxTasks: [TaskItem] {
        let base = tasks.filter { [.inbox, .shrunk, .snoozed, .moved].contains($0.status) }
        let filtered = hideNonEssentials
            ? base.filter { $0.priority == .essential || $0.priority == .important }
            : base
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.lg) {
                GentleSectionHeader(
                    title: "Inbox",
                    subtitle: hideNonEssentials
                        ? "Filtered to essentials only."
                        : "Unscheduled tasks. Nothing here is judging you."
                )

                if hideNonEssentials {
                    HStack(spacing: GentleTheme.Spacing.sm) {
                        Image(systemName: "eye.slash.fill")
                            .imageScale(.small)
                            .foregroundStyle(GentleTheme.primary)
                        Text("Non-essentials are hidden.")
                            .font(GentleTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(GentleTheme.textPrimary)
                        Spacer()
                        Button("Show all") { hideNonEssentials = false }
                            .font(GentleTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(GentleTheme.primary)
                    }
                    .padding(GentleTheme.Spacing.md)
                    .background(GentleTheme.primary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
                }

                if inboxTasks.isEmpty {
                    GentleEmptyState(
                        title: hideNonEssentials ? "No essentials right now" : "Your inbox is clear",
                        message: hideNonEssentials
                            ? "Mark something Important or Essential, or show all tasks."
                            : "Capture something whenever it appears. It can stay simple.",
                        systemImage: "tray"
                    )
                } else {
                    ForEach(inboxTasks) { task in
                        GentleTaskCard(
                            task: task,
                            layout: .compact,
                            primaryAction: GentleTaskAction(
                                title: "Done",
                                systemImage: "checkmark.circle.fill",
                                role: .primary,
                                action: { TaskActionService.markTaskDone(task, context: modelContext) }
                            ),
                            secondaryActions: [
                                GentleTaskAction(
                                    title: "Edit",
                                    systemImage: "pencil",
                                    action: { editingTask = task }
                                ),
                                GentleTaskAction(
                                    title: "Schedule",
                                    systemImage: "calendar.badge.plus",
                                    action: { TaskActionService.scheduleSoon(task, preferences: preferences.first, context: modelContext) }
                                )
                            ],
                            overflowActions: [
                                GentleTaskAction(
                                    title: "Shrink",
                                    systemImage: "arrow.down.right.and.arrow.up.left",
                                    action: { TaskActionService.shrinkTask(task, context: modelContext) }
                                ),
                                GentleTaskAction(
                                    title: "Delete",
                                    systemImage: "trash",
                                    role: .destructive,
                                    action: { taskPendingDelete = task }
                                )
                            ]
                        )
                    }
                }
            }
            .padding(GentleTheme.Spacing.screenHorizontal)
            .gentleBottomSafePad()
        }
        .gentleBackground()
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTask) { task in
            NavigationStack {
                TaskEditView(task: task)
            }
        }
        .confirmationDialog(
            "Delete this task?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Delete Task", role: .destructive) {
                if let taskPendingDelete {
                    delete(taskPendingDelete)
                }
                taskPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                taskPendingDelete = nil
            }
        } message: {
            Text("This removes the task from Gentle Day. Scheduled blocks made from it may remain unless you delete them too.")
        }
    }

    private func delete(_ task: TaskItem) {
        modelContext.delete(task)
        try? modelContext.save()
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { taskPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    taskPendingDelete = nil
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        InboxView()
    }
    .modelContainer(PersistenceController.makeModelContainer())
}
