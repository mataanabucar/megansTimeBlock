import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var preferences: [UserPlanningPreferences]
    @State private var editingTask: TaskItem?

    private var inboxTasks: [TaskItem] {
        tasks
            .filter { [.inbox, .shrunk, .snoozed, .moved].contains($0.status) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GentleSectionHeader(
                    title: "Inbox",
                    subtitle: "Unsorted life tasks. Nothing here is judging you."
                )

                if inboxTasks.isEmpty {
                    GentleEmptyState(
                        title: "Your inbox is clear",
                        message: "Capture something whenever it appears. It can stay simple.",
                        systemImage: "tray"
                    )
                } else {
                    ForEach(inboxTasks) { task in
                        InboxTaskCard(
                            task: task,
                            onEdit: { editingTask = task },
                            onSchedule: { TaskActionService.scheduleSoon(task, preferences: preferences.first, context: modelContext) },
                            onDone: { TaskActionService.markTaskDone(task, context: modelContext) },
                            onShrink: { TaskActionService.shrinkTask(task, context: modelContext) },
                            onDelete: { delete(task) }
                        )
                    }
                }
            }
            .padding(20)
        }
        .gentleBackground()
        .navigationTitle("Inbox")
        .sheet(item: $editingTask) { task in
            NavigationStack {
                TaskEditView(task: task)
            }
        }
    }

    private func delete(_ task: TaskItem) {
        modelContext.delete(task)
        try? modelContext.save()
    }
}

private struct InboxTaskCard: View {
    var task: TaskItem
    var onEdit: () -> Void
    var onSchedule: () -> Void
    var onDone: () -> Void
    var onShrink: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(GentleTheme.color(for: task.category))
                    .frame(width: 14, height: 14)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(GentleTheme.ink)
                    GentleMetadataRow(items: metadata)
                }

                Spacer()
            }

            if !task.suggestedTinyStep.isEmpty {
                Text("Tiny step: \(task.suggestedTinyStep)")
                    .font(.subheadline)
                    .foregroundStyle(GentleTheme.mutedInk)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                Button("Edit", action: onEdit)
                Button("Schedule", action: onSchedule)
                Button("Done", action: onDone)
                Button("Shrink", action: onShrink)
                Button(role: .destructive, action: onDelete) {
                    Text("Delete")
                }
            }
            .buttonStyle(.bordered)
            .tint(GentleTheme.sage)
        }
        .gentleCardStyle()
    }

    private var metadata: [String] {
        var values = [
            task.category.title,
            "\(task.estimatedMinutes) min",
            task.energyLevel.title,
            task.status.title
        ]

        if let dueDate = task.dueDate {
            values.insert(DateFormatting.shortDate.string(from: dueDate), at: 2)
        }

        return values
    }
}

