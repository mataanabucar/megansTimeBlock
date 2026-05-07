import SwiftData
import SwiftUI

struct BuildPlanView: View {
    @Environment(\.gentleActiveTab) private var gentleActiveTab
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var blocks: [ScheduleBlock]
    @Query private var preferences: [UserPlanningPreferences]
    @State private var viewModel = BuildPlanViewModel()

    private var openTaskCount: Int {
        tasks.filter { [.inbox, .shrunk, .snoozed, .moved].contains($0.status) }.count
    }

    private var primaryStyles: [PlanningStyle] {
        [.balancedDay, .lightDay, .catchUpDay, .errandsDay]
    }

    var body: some View {
        GentleScrollView(spacing: 19, topPadding: 14) {
            topBar

            GentlePageHeader(
                title: "Build My Day",
                subtitle: "Create a gentle plan that fits your day and energy.",
                systemImage: "calendar",
                centered: true
            )
            .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 11) {
                Text("Plan range")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.slate)
                PlanRangeControl(selection: $viewModel.selectedRange)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Choose a planning style")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.slate)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(primaryStyles) { style in
                        PlanningStyleTile(
                            style: style,
                            isSelected: viewModel.selectedStyle == style,
                            tint: styleTint(style)
                        ) {
                            viewModel.selectedStyle = style
                        }
                    }
                }
            }

            AvailableTimeCard(
                preference: preferences.first,
                openTaskCount: openTaskCount
            )

            GentlePrimaryButton(
                title: viewModel.isGenerating ? "Building..." : "Generate Gentle Plan",
                systemImage: "sparkles"
            ) {
                generatePlan()
            }
            .disabled(viewModel.isGenerating || preferences.first == nil)
            .opacity(viewModel.isGenerating || preferences.first == nil ? 0.55 : 1)

            if let response = viewModel.response {
                PlanResponseView(response: response)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.peach)
                    .gentleCardStyle()
            }
        }
        .gentleBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            gentleActiveTab?.wrappedValue = .plan
            if let preference = preferences.first, viewModel.response == nil {
                viewModel.applyDefaults(from: preference)
            }
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

    private func generatePlan() {
        guard let preference = preferences.first else { return }
        Task {
            guard let response = await viewModel.generate(
                tasks: tasks,
                existingScheduleBlocks: blocks,
                preferences: preference
            ) else { return }

            persist(response)
        }
    }

    @MainActor
    private func persist(_ response: AIScheduleBuildResponse) {
        for plannedBlock in response.proposedBlocks {
            let alreadyExists = blocks.contains { existing in
                existing.taskId == plannedBlock.taskId && existing.status != .done && existing.status != .skipped
            }
            guard !alreadyExists else { continue }

            let block = ScheduleBlock(
                taskId: plannedBlock.taskId,
                title: plannedBlock.title,
                startTime: plannedBlock.startTime,
                endTime: plannedBlock.endTime,
                flexibleWindowLabel: plannedBlock.flexibleWindowLabel,
                category: plannedBlock.category,
                reminderStyle: plannedBlock.reminderStyle,
                aiReason: plannedBlock.aiReason ?? ""
            )
            modelContext.insert(block)

            if let task = tasks.first(where: { $0.id == plannedBlock.taskId }) {
                task.status = .scheduled
                Task {
                    try? await ReminderService.shared.scheduleReminder(for: block, task: task)
                }
            }
        }

        try? modelContext.save()
    }

    private func styleTint(_ style: PlanningStyle) -> Color {
        switch style {
        case .balancedDay: GentleTheme.sage
        case .lightDay: GentleTheme.sky
        case .catchUpDay: GentleTheme.peach
        case .errandsDay: GentleTheme.butter
        case .homeReset: GentleTheme.lilac
        case .minimumDay: GentleTheme.sage
        }
    }
}

private struct PlanRangeControl: View {
    @Binding var selection: ScheduleRange

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ScheduleRange.allCases) { range in
                Button {
                    selection = range
                } label: {
                    Text(range.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selection == range ? AppColors.lavenderDeep : AppColors.slate)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selection == range ? AppColors.lavenderSoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(AppColors.softBorder.opacity(0.65), lineWidth: 0.8)
        }
    }
}

private struct PlanningStyleTile: View {
    var style: PlanningStyle
    var isSelected: Bool
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: iconName)
                    .font(.system(size: 25, weight: .regular))
                    .foregroundStyle(tint)

                Text(style.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.navy)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(style.friendlyDescription)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppColors.mutedText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, minHeight: 112)
            .padding(13)
            .background(tint.opacity(0.11))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                    .stroke(isSelected ? AppColors.lavender : AppColors.softBorder.opacity(0.48), lineWidth: isSelected ? 1.2 : 0.7)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch style {
        case .balancedDay: "scalemass"
        case .lightDay: "leaf"
        case .catchUpDay: "arrow.clockwise"
        case .errandsDay: "cart.fill"
        case .homeReset: "house.fill"
        case .minimumDay: "sparkle"
        }
    }
}

private struct AvailableTimeCard: View {
    var preference: UserPlanningPreferences?
    var openTaskCount: Int

    var body: some View {
        SoftCard(innerPadding: 15) {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppColors.navy)
                    .frame(width: 30, height: 30)
                    .background(AppColors.skySoft)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Your available time")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.mutedText)
                    Text(timeRange)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundStyle(AppColors.navy)
                    Text("\(durationLabel) • \(openTaskCount) inbox item\(openTaskCount == 1 ? "" : "s")")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.mutedText)
                }

                Spacer()

                Button("Edit") {}
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.lavenderDeep)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(AppColors.lavenderSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var timeRange: String {
        guard let preference else { return "6:00 PM - 9:30 PM" }
        return DateFormatting.timeRange(
            start: preference.defaultWindowStart,
            end: preference.defaultWindowEnd
        )
    }

    private var durationLabel: String {
        guard let preference else { return "About 3.5 hours" }
        let minutes = max(
            0,
            Calendar.current.dateComponents(
                [.minute],
                from: preference.defaultWindowStart,
                to: preference.defaultWindowEnd
            ).minute ?? 0
        )

        if minutes == 0 {
            return "Flexible window"
        }

        let hours = Double(minutes) / 60
        return "About \(hours.formatted(.number.precision(.fractionLength(hours.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)))) hours"
    }
}

private struct PlanResponseView: View {
    var response: AIScheduleBuildResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(response.friendlySummary)
                .font(AppTypography.bodyEmphasis)
                .foregroundStyle(AppColors.navy)

            ForEach(response.warnings) { warning in
                VStack(alignment: .leading, spacing: 5) {
                    Text(warning.message)
                        .font(AppTypography.callout.weight(.semibold))
                        .foregroundStyle(AppColors.navy)
                    if let taskTitle = warning.taskTitle?.nilIfBlank {
                        Text(taskTitle)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.mutedText)
                    }
                }
                .padding(12)
                .background(AppColors.butterSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            ForEach(response.proposedBlocks) { block in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(GentleTheme.color(for: block.category))
                        .frame(width: 12, height: 12)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.title)
                            .font(AppTypography.bodyEmphasis)
                            .foregroundStyle(AppColors.navy)
                        Text("\(block.flexibleWindowLabel) · \(DateFormatting.timeRange(start: block.startTime, end: block.endTime))")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.mutedText)
                    }
                    Spacer()
                }
            }
        }
        .gentleCardStyle()
    }
}
