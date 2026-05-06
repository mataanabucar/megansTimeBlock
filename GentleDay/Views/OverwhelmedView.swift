import SwiftData
import SwiftUI

private struct OverwhelmTinyAction: Identifiable {
    let id = UUID()
    var taskId: UUID?
    var title: String
    var minutes: Int
}

struct OverwhelmedView: View {
    @Environment(\.gentleActiveTab) private var gentleActiveTab
    @Environment(\.dismiss) private var dismiss
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
        GentleScrollView(spacing: 22, topPadding: 14) {
            topBar

            GentlePageHeader(
                title: "I'm\nOverwhelmed",
                subtitle: "Let's make it smaller.\nYou don't have to do it all.",
                systemImage: "cloud",
                centered: true
            )
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Choose one tiny thing")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.slate)

                VStack(spacing: 11) {
                    ForEach(Array(tinyActions.enumerated()), id: \.element.id) { index, action in
                        TinyActionRow(action: action, index: index) {
                            complete(action)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Reset options")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.slate)

                HStack(spacing: 9) {
                    resetButton("2-minute\nreset", background: AppColors.peachSoft) {
                        message = "Try water, one breath, and one visible surface."
                    }
                    resetButton("5-minute\nreset", background: AppColors.lavenderSoft) {
                        message = "Set a short timer and stop when it rings."
                    }
                    resetButton("One tiny\ntask", background: AppColors.sageSoft) {
                        message = "Choose the smallest useful step above."
                    }
                }
            }

            SoftCard(background: AppColors.blushSoft, stroke: AppColors.blush.opacity(0.16), innerPadding: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.blush)
                        .frame(width: 38, height: 38)
                        .background(AppColors.card.opacity(0.75))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("This is enough for now.")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundStyle(AppColors.navy)
                        Text(message == "This is enough for now." ? "Small steps still move you forward." : message)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.mutedText)
                    }

                    Spacer()
                }
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
        }
    }

    private func resetButton(
        _ title: String,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.navy)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .stroke(AppColors.softBorder.opacity(0.42), lineWidth: 0.7)
                }
        }
        .buttonStyle(.plain)
    }

    private func complete(_ action: OverwhelmTinyAction) {
        if let task = tasks.first(where: { $0.id == action.taskId }) {
            task.status = .done
            try? modelContext.save()
        }
        message = "This is enough for now."
    }
}

private struct TinyActionRow: View {
    var action: OverwhelmTinyAction
    var index: Int
    var onComplete: () -> Void

    var body: some View {
        Button(action: onComplete) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(background)
                    .clipShape(Circle())

                Text(action.title)
                    .font(AppTypography.bodyEmphasis)
                    .foregroundStyle(AppColors.navy)
                    .lineLimit(1)

                Spacer()

                Text("\(action.minutes) min")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.mutedText)
            }
            .padding(14)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                    .stroke(AppColors.softBorder.opacity(0.55), lineWidth: 0.7)
            }
            .shadow(color: DesignTokens.cardShadow.color, radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch index {
        case 0: "drop.fill"
        case 1: "tshirt.fill"
        default: "takeoutbag.and.cup.and.straw.fill"
        }
    }

    private var tint: Color {
        switch index {
        case 0: AppColors.sky
        case 1: AppColors.sky
        default: AppColors.mint
        }
    }

    private var background: Color {
        switch index {
        case 0: AppColors.skySoft
        case 1: AppColors.skySoft
        default: AppColors.mintSoft
        }
    }
}
