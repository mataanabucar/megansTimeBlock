import SwiftData
import SwiftUI

private struct OverwhelmTinyAction: Identifiable {
    let id = UUID()
    var taskId: UUID?
    var title: String
    var minutes: Int
    var systemImage: String
    var tint: Color
}

struct OverwhelmedView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @AppStorage("gentle.hideNonEssentials") private var hideNonEssentials = false
    @State private var message = "This is enough for now."
    @State private var navigateToPlanTomorrow = false

    private var tinyActions: [OverwhelmTinyAction] {
        let openTasks = tasks
            .filter { [.inbox, .shrunk, .snoozed, .moved].contains($0.status) }
            .sorted { lhs, rhs in
                if lhs.estimatedMinutes != rhs.estimatedMinutes { return lhs.estimatedMinutes < rhs.estimatedMinutes }
                return lhs.createdAt < rhs.createdAt
            }
            .prefix(3)
            .map { task -> OverwhelmTinyAction in
                OverwhelmTinyAction(
                    taskId: task.id,
                    title: task.suggestedTinyStep.nilIfBlank ?? task.title,
                    minutes: min(task.estimatedMinutes, 10),
                    systemImage: GentleTaskCard.icon(for: task.category),
                    tint: GentleTheme.color(for: task.category)
                )
            }

        var actions = Array(openTasks)
        let fallback: [OverwhelmTinyAction] = [
            OverwhelmTinyAction(taskId: nil, title: "Drink water", minutes: 1, systemImage: "drop.fill", tint: GentleTheme.sky),
            OverwhelmTinyAction(taskId: nil, title: "Set a two-minute timer", minutes: 2, systemImage: "timer", tint: GentleTheme.lilac),
            OverwhelmTinyAction(taskId: nil, title: "Put dishes in sink", minutes: 2, systemImage: "fork.knife", tint: GentleTheme.peach)
        ]

        for item in fallback where actions.count < 3 {
            actions.append(item)
        }

        return Array(actions.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xl) {
                header
                tinyActionsSection
                resetSection
                messageCard
                footer
            }
            .padding(GentleTheme.Spacing.screenHorizontal)
            .gentleBottomSafePad()
        }
        .gentleBackground()
        .navigationTitle("Overwhelmed")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToPlanTomorrow) {
            BuildPlanView(initialRange: .tomorrow, initialStyle: .minimumDay)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.sm) {
            Text("I'm Overwhelmed")
                .font(GentleTheme.Typography.displayLarge)
                .foregroundStyle(GentleTheme.textPrimary)
            Text("Let's make this smaller. Pick one tiny thing, or just reset.")
                .font(GentleTheme.Typography.body)
                .foregroundStyle(GentleTheme.textSecondary)
        }
    }

    private var tinyActionsSection: some View {
        VStack(spacing: GentleTheme.Spacing.md) {
            ForEach(tinyActions) { action in
                Button {
                    complete(action)
                } label: {
                    HStack(spacing: GentleTheme.Spacing.md) {
                        GentleIconBadge(systemName: action.systemImage, tint: action.tint, size: .medium)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                                .font(GentleTheme.Typography.headline)
                                .foregroundStyle(GentleTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                            Text("\(action.minutes) min")
                                .font(GentleTheme.Typography.caption)
                                .foregroundStyle(GentleTheme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(GentleTheme.primary)
                            .accessibilityHidden(true)
                    }
                    .padding(GentleTheme.Spacing.cardPadding)
                    .background(GentleTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous)
                            .stroke(GentleTheme.outline, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous))
                    .shadow(color: GentleTheme.Shadow.cardColor, radius: GentleTheme.Shadow.cardRadius, x: 0, y: GentleTheme.Shadow.cardYOffset)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(action.title), \(action.minutes) minutes")
            }
        }
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            GentleSectionHeader(title: "Reset modes", subtitle: "Lower the bar. None of these need to be perfect.")

            VStack(spacing: GentleTheme.Spacing.md) {
                ForEach(OverwhelmResetOption.allCases) { option in
                    GentleModeCard(
                        title: option.title,
                        subtitle: optionSubtitle(option),
                        systemImage: option.systemImage,
                        tint: tint(for: option),
                        isSelected: isOptionActive(option),
                        action: { handle(option) }
                    )
                }
            }
        }
    }

    private var messageCard: some View {
        Text(message)
            .font(GentleTheme.Typography.bodyEmphasized)
            .foregroundStyle(GentleTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gentleCardStyle()
    }

    private var footer: some View {
        Text("This can stay small.")
            .font(GentleTheme.Typography.compassionate)
            .foregroundStyle(GentleTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, GentleTheme.Spacing.lg)
    }

    // MARK: - Helpers

    private func complete(_ action: OverwhelmTinyAction) {
        if let task = tasks.first(where: { $0.id == action.taskId }) {
            task.status = .done
            try? modelContext.save()
        }
        message = "Done. This is enough for now."
    }

    private func optionSubtitle(_ option: OverwhelmResetOption) -> String {
        switch option {
        case .twoMinuteReset: return option.subtitle
        case .hideNonEssentials:
            return hideNonEssentials
                ? "On — Inbox is filtered to essentials."
                : option.subtitle
        case .planTomorrow: return option.subtitle
        }
    }

    private func tint(for option: OverwhelmResetOption) -> Color {
        switch option {
        case .twoMinuteReset: GentleTheme.lilac
        case .hideNonEssentials: GentleTheme.sky
        case .planTomorrow: GentleTheme.sage
        }
    }

    private func isOptionActive(_ option: OverwhelmResetOption) -> Bool {
        switch option {
        case .hideNonEssentials: return hideNonEssentials
        default: return false
        }
    }

    private func handle(_ option: OverwhelmResetOption) {
        switch option {
        case .twoMinuteReset:
            message = "Two minutes. Drink water. Notice one thing in the room."
        case .hideNonEssentials:
            hideNonEssentials.toggle()
            message = hideNonEssentials
                ? "Inbox is now filtered to essentials only. You can turn this off anytime."
                : "Showing the full inbox again."
        case .planTomorrow:
            navigateToPlanTomorrow = true
        }
    }
}

#Preview {
    NavigationStack {
        OverwhelmedView()
    }
    .modelContainer(PersistenceController.makeModelContainer())
}
