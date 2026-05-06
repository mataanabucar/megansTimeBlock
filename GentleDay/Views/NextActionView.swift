import SwiftData
import SwiftUI

struct NextActionView: View {
    @Environment(\.gentleActiveTab) private var gentleActiveTab
    @Environment(\.dismiss) private var dismiss
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

    private var secondarySuggestions: [TaskItem] {
        let excludedTaskID = recommendation?.taskId
        return tasks
            .filter { [.inbox, .shrunk, .snoozed, .moved].contains($0.status) }
            .filter { $0.id != excludedTaskID }
            .sorted { lhs, rhs in
                if lhs.estimatedMinutes != rhs.estimatedMinutes {
                    return lhs.estimatedMinutes < rhs.estimatedMinutes
                }
                return lhs.createdAt < rhs.createdAt
            }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        GentleScrollView(spacing: 20, topPadding: 14) {
            topBar

            GentlePageHeader(
                title: "What Should\nI Do Next?",
                subtitle: "Based on your plan and energy.",
                systemImage: "lightbulb",
                centered: true
            )

            if let recommendation {
                Button {
                    start(recommendation)
                } label: {
                    PrimaryRecommendationCard(recommendation: recommendation)
                }
                .buttonStyle(.plain)

                if let starterMessage {
                    Text(starterMessage)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.mutedText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if !secondarySuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("Other good options")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.slate)

                        VStack(spacing: 10) {
                            ForEach(secondarySuggestions) { task in
                                SuggestionRow(task: task) {
                                    start(
                                        NextActionRecommendation(
                                            taskId: task.id,
                                            blockId: nil,
                                            title: task.title,
                                            reason: "This is a simple place to begin.",
                                            tinyStep: task.suggestedTinyStep,
                                            minutes: min(task.estimatedMinutes, 10)
                                        )
                                    )
                                }
                            }
                        }
                    }
                }

                NavigationLink {
                    TodayScheduleView()
                } label: {
                    HStack {
                        Text("See full plan")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundStyle(AppColors.navy)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.faintText)
                    }
                    .padding(17)
                    .background(AppColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                            .stroke(AppColors.softBorder.opacity(0.62), lineWidth: 0.8)
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Snooze") {
                        snooze(recommendation)
                    }
                    Button("Pick another") {
                        skippedRecommendationIDs.insert(recommendation.taskId ?? recommendation.blockId ?? recommendation.id)
                    }
                }
            } else {
                GentleEmptyState(
                    title: "Nothing is asking for a next step",
                    message: "You can capture something, build a day, or take a quiet reset.",
                    systemImage: "sparkles"
                )
            }
        }
        .gentleBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            gentleActiveTab?.wrappedValue = .plan
        }
    }

    private var topBar: some View {
        HStack {
            SoftIconButton(systemImage: "chevron.left") {
                dismiss()
            }
            Spacer()
            GentleLogoMark(size: 34)
        }
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

private struct PrimaryRecommendationCard: View {
    var recommendation: NextActionRecommendation

    var body: some View {
        SoftCard(background: AppColors.sageSoft, stroke: AppColors.sage.opacity(0.24), cornerRadius: 25, innerPadding: 22) {
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(AppColors.sky)
                        .frame(width: 42, height: 42)
                        .background(AppColors.skySoft)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 9) {
                        Text(recommendation.title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppColors.navy)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(recommendation.reason)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.slate)
                            .lineSpacing(3)
                    }
                }

                HStack(spacing: 10) {
                    PillChip(
                        title: "\(recommendation.minutes) min",
                        systemImage: "clock",
                        tint: AppColors.sage,
                        background: AppColors.card.opacity(0.72)
                    )

                    Text(recommendation.tinyStep)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.mutedText)
                        .lineLimit(2)
                }
            }
        }
    }
}

private struct SuggestionRow: View {
    var task: TaskItem
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CategoryIconBadge(category: task.category, size: 34)

                Text(task.title)
                    .font(AppTypography.bodyEmphasis)
                    .foregroundStyle(AppColors.navy)
                    .lineLimit(1)

                Spacer()

                Text("\(task.estimatedMinutes) min")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.mutedText)
            }
            .padding(15)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                    .stroke(AppColors.softBorder.opacity(0.55), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NextActionView()
        .modelContainer(PersistenceController.makeModelContainer())
}
