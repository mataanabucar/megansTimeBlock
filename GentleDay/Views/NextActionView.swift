import SwiftData
import SwiftUI

struct NextActionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var blocks: [ScheduleBlock]
    @State private var viewModel = NextActionViewModel()
    @State private var skippedRecommendationIDs: Set<UUID> = []
    @State private var starterMessage: String?

    private var availableTasks: [TaskItem] {
        tasks.filter { !skippedRecommendationIDs.contains($0.id) }
    }

    private var availableBlocks: [ScheduleBlock] {
        blocks.filter { !skippedRecommendationIDs.contains($0.id) }
    }

    private var recommendation: NextActionRecommendation? {
        viewModel.recommendation(tasks: availableTasks, blocks: availableBlocks)
    }

    private var alternates: [NextActionRecommendation] {
        viewModel.topAlternatives(count: 3, tasks: availableTasks, blocks: availableBlocks)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xl) {
                header
                if let recommendation {
                    heroCard(recommendation)
                    if !alternates.isEmpty {
                        alternatesSection
                    }
                    seeFullPlanLink
                } else {
                    GentleEmptyState(
                        title: "Nothing is asking for a next step",
                        message: "You can capture something, build a day, or take a quiet reset.",
                        systemImage: "sparkles"
                    )
                }
            }
            .padding(GentleTheme.Spacing.screenHorizontal)
            .gentleBottomSafePad()
        }
        .gentleBackground()
        .navigationTitle("Next Step")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.sm) {
            Text("What Should I Do Next?")
                .font(GentleTheme.Typography.displayLarge)
                .foregroundStyle(GentleTheme.textPrimary)
            Text("Based on your plan and energy.")
                .font(GentleTheme.Typography.body)
                .foregroundStyle(GentleTheme.textSecondary)
        }
    }

    private func heroCard(_ rec: NextActionRecommendation) -> some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xs) {
                Text("PRIMARY RECOMMENDATION")
                    .font(GentleTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(GentleTheme.primary)
                Text(rec.title)
                    .font(GentleTheme.Typography.displayMedium)
                    .foregroundStyle(GentleTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: GentleTheme.Spacing.sm) {
                GentleChip(title: "\(rec.minutes) min", tint: GentleTheme.butter)
                if rec.blockId != nil {
                    GentleChip(title: "In your plan", tint: GentleTheme.sage)
                } else {
                    GentleChip(title: "From inbox", tint: GentleTheme.peach)
                }
            }

            Text(rec.reason)
                .font(GentleTheme.Typography.body)
                .foregroundStyle(GentleTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !rec.tinyStep.isEmpty {
                tinyStepBox(rec.tinyStep)
            }

            GentleButton(
                title: "Start \(rec.minutes)-minute timer",
                systemImage: "timer",
                role: .primary,
                action: { start(rec) }
            )

            if let starterMessage {
                Text(starterMessage)
                    .font(GentleTheme.Typography.subheadline)
                    .foregroundStyle(GentleTheme.textSecondary)
            }

            HStack(spacing: GentleTheme.Spacing.sm) {
                GentleButton(title: "Snooze", systemImage: "alarm.fill", role: .secondary, action: { snooze(rec) })
                GentleButton(title: "Pick another", systemImage: "shuffle", role: .secondary, action: {
                    skippedRecommendationIDs.insert(rec.taskId ?? rec.blockId ?? rec.id)
                })
            }
        }
        .gentleCardStyle()
    }

    private func tinyStepBox(_ step: String) -> some View {
        HStack(alignment: .top, spacing: GentleTheme.Spacing.sm) {
            Image(systemName: "leaf.fill")
                .imageScale(.small)
                .foregroundStyle(GentleTheme.textPrimary)
                .padding(6)
                .background(GentleTheme.sage.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tiny step")
                    .font(GentleTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(GentleTheme.textSecondary)
                Text(step)
                    .font(GentleTheme.Typography.body)
                    .foregroundStyle(GentleTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GentleTheme.Spacing.md)
        .background(GentleTheme.sage.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
    }

    private var alternatesSection: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            GentleSectionHeader(
                title: "Other good options",
                subtitle: "If today's first idea doesn't feel right."
            )
            VStack(spacing: GentleTheme.Spacing.md) {
                ForEach(alternates) { alt in
                    Button {
                        skippedRecommendationIDs.insert(alt.id)
                    } label: {
                        HStack(spacing: GentleTheme.Spacing.md) {
                            GentleIconBadge(systemName: "circle.dotted", tint: GentleTheme.lilac, size: .medium)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alt.title)
                                    .font(GentleTheme.Typography.headline)
                                    .foregroundStyle(GentleTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(alt.minutes) min · \(alt.reason)")
                                    .font(GentleTheme.Typography.caption)
                                    .foregroundStyle(GentleTheme.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }
                        .padding(GentleTheme.Spacing.cardPadding)
                        .background(GentleTheme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous)
                                .stroke(GentleTheme.outline, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Make \(alt.title) the next step")
                }
            }
        }
    }

    private var seeFullPlanLink: some View {
        NavigationLink {
            TodayScheduleView()
        } label: {
            Label("See full plan", systemImage: "calendar")
                .font(GentleTheme.Typography.button)
                .frame(maxWidth: .infinity)
                .padding(.vertical, GentleTheme.Spacing.md + 2)
                .padding(.horizontal, GentleTheme.Spacing.lg)
                .foregroundStyle(GentleTheme.textPrimary)
                .background(GentleTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous)
                        .stroke(GentleTheme.outline, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

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

#Preview {
    NavigationStack {
        NextActionView()
    }
    .modelContainer(PersistenceController.makeModelContainer())
}
