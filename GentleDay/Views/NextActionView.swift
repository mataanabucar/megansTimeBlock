import SwiftData
import SwiftUI

struct NextActionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var blocks: [ScheduleBlock]
    @State private var viewModel = NextActionViewModel()
    @State private var skippedRecommendationIDs: Set<UUID> = []
    @State private var starterMessage: String?

    private var recommendation: NextActionRecommendation? {
        guard let first = viewModel.recommendation(tasks: tasks, blocks: blocks) else { return nil }
        if skippedRecommendationIDs.contains(first.taskId ?? first.blockId ?? first.id) {
            let filteredTasks = tasks.filter { $0.id != first.taskId }
            let filteredBlocks = blocks.filter { $0.id != first.blockId }
            return viewModel.recommendation(tasks: filteredTasks, blocks: filteredBlocks)
        }
        return first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                GentleSectionHeader(
                    title: "What Should I Do Next?",
                    subtitle: "Just one recommendation."
                )

                if let recommendation {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Primary recommendation")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GentleTheme.mutedInk)
                        Text(recommendation.title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(GentleTheme.ink)
                        Text(recommendation.reason)
                            .font(.body)
                            .foregroundStyle(GentleTheme.mutedInk)
                        Text(recommendation.tinyStep)
                            .font(.headline)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GentleTheme.sage.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        GentlePrimaryButton(
                            title: "Start \(recommendation.minutes)-minute timer",
                            systemImage: "timer"
                        ) {
                            start(recommendation)
                        }

                        if let starterMessage {
                            Text(starterMessage)
                                .font(.subheadline)
                                .foregroundStyle(GentleTheme.mutedInk)
                        }

                        HStack {
                            Button("Snooze") {
                                snooze(recommendation)
                            }
                            Button("Pick another") {
                                skippedRecommendationIDs.insert(recommendation.taskId ?? recommendation.blockId ?? recommendation.id)
                            }
                            NavigationLink("Show full plan") {
                                TodayScheduleView()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(GentleTheme.sage)
                    }
                    .gentleCardStyle()
                } else {
                    GentleEmptyState(
                        title: "Nothing is asking for a next step",
                        message: "You can capture something, build a day, or take a quiet reset.",
                        systemImage: "sparkles"
                    )
                }
            }
            .padding(20)
        }
        .gentleBackground()
        .navigationTitle("Next Step")
    }

    private func start(_ recommendation: NextActionRecommendation) {
        if let block = blocks.first(where: { $0.id == recommendation.blockId }) {
            block.status = .inProgress
        }
        if let task = tasks.first(where: { $0.id == recommendation.taskId }) {
            task.status = .inProgress
        }
        try? modelContext.save()
        starterMessage = "A small starter is on. Stop when the first step is complete."
    }

    private func snooze(_ recommendation: NextActionRecommendation) {
        if let block = blocks.first(where: { $0.id == recommendation.blockId }) {
            TaskActionService.snoozeBlock(block, minutes: 15, tasks: tasks, context: modelContext)
        } else if let task = tasks.first(where: { $0.id == recommendation.taskId }) {
            task.status = .snoozed
            try? modelContext.save()
        }
        skippedRecommendationIDs.insert(recommendation.taskId ?? recommendation.blockId ?? recommendation.id)
    }
}

