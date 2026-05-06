import SwiftData
import SwiftUI

struct BuildPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @Query private var blocks: [ScheduleBlock]
    @Query private var preferences: [UserPlanningPreferences]
    @State private var viewModel = BuildPlanViewModel()

    private var openTaskCount: Int {
        tasks.filter { [.inbox, .shrunk, .snoozed, .moved].contains($0.status) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GentleSectionHeader(
                    title: "Build My Day",
                    subtitle: "A plan is a suggestion. You can move anything."
                )

                VStack(alignment: .leading, spacing: 14) {
                    Picker("Range", selection: $viewModel.selectedRange) {
                        ForEach(ScheduleRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    GentleSectionHeader(title: "Planning style", subtitle: viewModel.selectedStyle.friendlyDescription)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        ForEach(PlanningStyle.allCases) { style in
                            Button {
                                viewModel.selectedStyle = style
                            } label: {
                                GentlePill(
                                    title: style.title,
                                    tint: styleTint(style),
                                    isSelected: viewModel.selectedStyle == style
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .gentleCardStyle()

                VStack(alignment: .leading, spacing: 10) {
                    Text("\(openTaskCount) inbox item\(openTaskCount == 1 ? "" : "s") available")
                        .font(.headline)
                        .foregroundStyle(GentleTheme.ink)
                    Text("Extra items stay in the inbox instead of being forced into the day.")
                        .font(.subheadline)
                        .foregroundStyle(GentleTheme.mutedInk)
                }
                .gentleCardStyle()

                GentlePrimaryButton(
                    title: viewModel.isGenerating ? "Building..." : "Generate Gentle Plan",
                    systemImage: "wand.and.stars"
                ) {
                    generatePlan()
                }
                .disabled(viewModel.isGenerating || preferences.first == nil)
                .opacity(viewModel.isGenerating || preferences.first == nil ? 0.55 : 1)

                NavigationLink {
                    TodayScheduleView()
                } label: {
                    Label("Open Today Schedule", systemImage: "calendar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(GentleTheme.sky.opacity(0.22))
                        .foregroundStyle(GentleTheme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                if let response = viewModel.response {
                    PlanResponseView(response: response)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .gentleCardStyle()
                }
            }
            .padding(20)
        }
        .gentleBackground()
        .navigationTitle("Plan")
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
    private func persist(_ response: AIPlanResponse) {
        for plannedBlock in response.proposedScheduleBlocks {
            let alreadyExists = blocks.contains { existing in
                existing.taskId == plannedBlock.taskId && existing.status != .done && existing.status != .skipped
            }
            guard !alreadyExists else { continue }

            let block = ScheduleBlock(
                id: plannedBlock.id,
                taskId: plannedBlock.taskId,
                title: plannedBlock.title,
                startTime: plannedBlock.startTime,
                endTime: plannedBlock.endTime,
                flexibleWindowLabel: plannedBlock.flexibleWindowLabel,
                category: plannedBlock.category,
                reminderStyle: plannedBlock.reminderStyle,
                aiReason: plannedBlock.aiReason
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

private struct PlanResponseView: View {
    var response: AIPlanResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(response.friendlySummary)
                .font(.headline)
                .foregroundStyle(GentleTheme.ink)

            ForEach(response.warnings) { warning in
                VStack(alignment: .leading, spacing: 5) {
                    Text(warning.message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GentleTheme.ink)
                    if let suggestion = warning.suggestion {
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(GentleTheme.mutedInk)
                    }
                }
                .padding(12)
                .background(GentleTheme.butter.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            ForEach(response.proposedScheduleBlocks) { block in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(GentleTheme.color(for: block.category))
                        .frame(width: 12, height: 12)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(block.title)
                            .font(.headline)
                        Text("\(block.flexibleWindowLabel) · \(DateFormatting.timeRange(start: block.startTime, end: block.endTime))")
                            .font(.caption)
                            .foregroundStyle(GentleTheme.mutedInk)
                    }
                    Spacer()
                }
            }
        }
        .gentleCardStyle()
    }
}

