import SwiftData
import SwiftUI

struct TaskEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem
    @State private var hasDueDate = false
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Title") {
                TextField("Task title", text: $task.title)
                Stepper("Duration: \(task.estimatedMinutes) min", value: $task.estimatedMinutes, in: 1...240, step: 5)
            }

            Section("Original capture") {
                Text(task.rawText)
                    .foregroundStyle(.secondary)
            }

            Section("Details") {
                Picker("Category", selection: categoryBinding) {
                    ForEach(categoryOptions) { category in
                        Text(category.title).tag(category)
                    }
                }

                Picker("Priority", selection: priorityBinding) {
                    ForEach(PriorityLevel.allCases) { priority in
                        Text(priority.title).tag(priority)
                    }
                }

                Picker("Energy", selection: energyBinding) {
                    ForEach(EnergyLevel.allCases) { energy in
                        Text(energy.title).tag(energy)
                    }
                }

                Toggle("Has a date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Date", selection: dueDateBinding, displayedComponents: [.date])
                }
            }

            Section("Gentle shrink options") {
                TextField("Tiny step", text: $task.suggestedTinyStep)
                ForEach(task.shrinkOptions, id: \.self) { option in
                    Text(option)
                }
            }

            Section {
                Button("Delete Task", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("Edit Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    task.touch()
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .confirmationDialog(
            "Delete this task?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Task", role: .destructive) {
                modelContext.delete(task)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .onAppear {
            hasDueDate = task.dueDate != nil
        }
        .onChange(of: hasDueDate) { _, enabled in
            if enabled && task.dueDate == nil {
                task.dueDate = Date()
            }
            if !enabled {
                task.dueDate = nil
            }
            task.touch()
        }
    }

    private var categoryBinding: Binding<TaskCategory> {
        Binding(
            get: { task.category },
            set: { task.category = $0 }
        )
    }

    private var categoryOptions: [TaskCategory] {
        TaskCategory.userSelectableCases.contains(task.category)
            ? TaskCategory.userSelectableCases
            : [task.category] + TaskCategory.userSelectableCases
    }

    private var priorityBinding: Binding<PriorityLevel> {
        Binding(
            get: { task.priority },
            set: { task.priority = $0 }
        )
    }

    private var energyBinding: Binding<EnergyLevel> {
        Binding(
            get: { task.energyLevel },
            set: { task.energyLevel = $0 }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { task.dueDate ?? Date() },
            set: {
                task.dueDate = $0
                task.touch()
            }
        )
    }
}
