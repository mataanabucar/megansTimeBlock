import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(\.gentleActiveTab) private var gentleActiveTab
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var preferences: [UserPlanningPreferences]
    @State private var editingTask: TaskItem?
    @State private var taskPendingDelete: TaskItem?

    private var inboxTasks: [TaskItem] {
        tasks
            .filter { [.inbox, .shrunk, .snoozed, .moved].contains($0.status) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        GentleScrollView(spacing: 20) {
            GentlePageHeader(
                title: "Inbox",
                subtitle: "Unscheduled tasks",
                trailingSystemImage: "slider.horizontal.3",
                trailingAction: {}
            )

            if inboxTasks.isEmpty {
                GentleEmptyState(
                    title: "Your inbox is clear",
                    message: "Capture something whenever it appears. It can stay simple.",
                    systemImage: "tray"
                )
            } else {
                VStack(spacing: 14) {
                    ForEach(inboxTasks) { task in
                        TaskRowCard(
                            title: task.title,
                            metadata: metadata(for: task),
                            category: task.category,
                            detail: task.suggestedTinyStep.nilIfBlank.map { "Tiny step: \($0)" },
                            actions: [
                                TaskRowAction(title: "Edit", systemImage: "pencil", action: { editingTask = task }),
                                TaskRowAction(title: "Schedule", systemImage: "calendar", action: {
                                    TaskActionService.scheduleSoon(task, preferences: preferences.first, context: modelContext)
                                }),
                                TaskRowAction(title: "Done", systemImage: "checkmark", tint: AppColors.success, action: {
                                    TaskActionService.markTaskDone(task, context: modelContext)
                                })
                            ]
                        )
                        .contextMenu {
                            Button("Shrink") {
                                TaskActionService.shrinkTask(task, context: modelContext)
                            }
                            Button("Delete", role: .destructive) {
                                taskPendingDelete = task
                            }
                        }
                    }
                }
            }
        }
        .gentleBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            gentleActiveTab?.wrappedValue = .inbox
        }
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

    private func metadata(for task: TaskItem) -> String {
        var values = [
            task.category.title,
            "\(task.estimatedMinutes) min"
        ]

        if let timingSummary = task.timingSummary?.nilIfBlank {
            values.append(timingSummary)
        } else if let dueDate = task.dueDate {
            values.append(dueLabel(for: dueDate))
        }

        return values.joined(separator: "  •  ")
    }

    private func dueLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Due Today"
        }

        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
           Calendar.current.isDate(date, inSameDayAs: tomorrow) {
            return "Due Tomorrow"
        }

        return DateFormatting.shortDate.string(from: date)
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
