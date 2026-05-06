import SwiftData
import SwiftUI

private struct OverwhelmTinyAction: Identifiable {
    let id = UUID()
    var taskId: UUID?
    var title: String
    var minutes: Int
}

struct OverwhelmedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @State private var message = "This is enough for now."

    private var tinyActions: [OverwhelmTinyAction] {
        let openTasks = tasks
            .filter { [.inbox, .shrunk, .snoozed, .moved].contains($0.status) }
            .sorted { lhs, rhs in
                if lhs.estimatedMinutes != rhs.estimatedMinutes { return lhs.estimatedMinutes < rhs.estimatedMinutes }
                return lhs.createdAt < rhs.createdAt
            }
            .prefix(3)
            .map {
                OverwhelmTinyAction(
                    taskId: $0.id,
                    title: $0.suggestedTinyStep.nilIfBlank ?? $0.title,
                    minutes: min($0.estimatedMinutes, 10)
                )
            }

        var actions = Array(openTasks)
        let fallback = [
            OverwhelmTinyAction(taskId: nil, title: "Drink water", minutes: 2),
            OverwhelmTinyAction(taskId: nil, title: "Put dishes in sink", minutes: 3),
            OverwhelmTinyAction(taskId: nil, title: "Start laundry", minutes: 5)
        ]

        for item in fallback where actions.count < 3 {
            actions.append(item)
        }

        return Array(actions.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("I'm Overwhelmed")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(GentleTheme.ink)
                    Text("The full list is hidden. Pick one tiny thing, or just reset.")
                        .font(.body)
                        .foregroundStyle(GentleTheme.mutedInk)
                }

                VStack(spacing: 12) {
                    ForEach(tinyActions) { action in
                        Button {
                            complete(action)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(action.title)
                                        .font(.headline)
                                    Text("\(action.minutes) min")
                                        .font(.caption)
                                        .foregroundStyle(GentleTheme.mutedInk)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle")
                                    .font(.title3)
                            }
                            .padding(16)
                            .background(GentleTheme.card)
                            .foregroundStyle(GentleTheme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Reset modes")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(GentleTheme.ink)
                    HStack {
                        Button("2-minute reset") { message = "Try water, one breath, and one visible surface." }
                        Button("5-minute reset") { message = "Set a short timer and stop when it rings." }
                        Button("One tiny task") { message = "Choose the smallest useful step above." }
                    }
                    .buttonStyle(.bordered)
                    .tint(GentleTheme.sage)
                }
                .gentleCardStyle()

                Text(message)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(GentleTheme.ink)
                    .frame(maxWidth: .infinity)
                    .gentleCardStyle()
            }
            .padding(20)
        }
        .gentleBackground()
        .navigationTitle("Overwhelmed")
    }

    private func complete(_ action: OverwhelmTinyAction) {
        if let task = tasks.first(where: { $0.id == action.taskId }) {
            task.status = .done
            try? modelContext.save()
        }
        message = "This is enough for now."
    }
}

