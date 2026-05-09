import SwiftData
import SwiftUI

private struct AIParseDraft: Identifiable {
    let id = UUID()
    let originalText: String
    let response: AITaskParseResponse
}

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [UserPlanningPreferences]
    @Query private var tasks: [TaskItem]
    @Query private var blocks: [ScheduleBlock]
    @State private var viewModel = QuickCaptureViewModel()
    @State private var aiDraft: AIParseDraft?
    @State private var isOrganizingWithAI = false
    @State private var aiMessage: String?
    @FocusState private var isRawTextFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.xxl) {
                header
                brainDumpCard
                chipsSection
            }
            .padding(GentleTheme.Spacing.screenHorizontal)
        }
        .scrollDismissesKeyboard(.interactively)
        .gentleBackground()
        .navigationTitle("Quick Capture")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            saveBar
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isRawTextFocused = false
                }
            }
        }
        .onDisappear {
            viewModel.stopVoiceCapture()
        }
        .sheet(item: $aiDraft) { draft in
            AIParsePreviewView(
                originalText: draft.originalText,
                response: draft.response,
                onSave: { saveAIResponse(draft.response) },
                onEditFirst: {
                    aiMessage = "You can adjust the text and try again."
                },
                onUseRawText: save
            )
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.sm) {
            Text("What do you need to do?")
                .font(GentleTheme.Typography.displayLarge)
                .foregroundStyle(GentleTheme.textPrimary)
            Text("Capture it all. We'll help sort it.")
                .font(GentleTheme.Typography.body)
                .foregroundStyle(GentleTheme.textSecondary)
        }
    }

    private var brainDumpCard: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $viewModel.rawText)
                    .font(GentleTheme.Typography.body)
                    .foregroundStyle(GentleTheme.textPrimary)
                    .tint(GentleTheme.primary)
                    .focused($isRawTextFocused)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .padding(GentleTheme.Spacing.md)
                    .background(GentleTheme.field)
                    .overlay {
                        RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous)
                            .stroke(viewModel.isListening ? GentleTheme.primary.opacity(0.7) : GentleTheme.outline, lineWidth: viewModel.isListening ? 1.5 : 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous))

                if viewModel.rawText.isEmpty {
                    Text("Type the brain dump here...")
                        .font(GentleTheme.Typography.body)
                        .foregroundStyle(GentleTheme.textSecondary.opacity(0.7))
                        .padding(.horizontal, GentleTheme.Spacing.md + 5)
                        .padding(.vertical, GentleTheme.Spacing.lg)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: GentleTheme.Spacing.sm) {
                voiceButton
                aiButton
            }

            if let message = viewModel.voiceMessage {
                Text(message)
                    .font(GentleTheme.Typography.caption)
                    .foregroundStyle(GentleTheme.textSecondary)
            }
            if let aiMessage {
                Text(aiMessage)
                    .font(GentleTheme.Typography.caption)
                    .foregroundStyle(GentleTheme.textSecondary)
            }
        }
    }

    private var voiceButton: some View {
        Button {
            toggleVoiceCapture()
        } label: {
            Label(viewModel.voiceButtonTitle, systemImage: viewModel.voiceButtonSystemImage)
                .font(GentleTheme.Typography.button)
                .frame(maxWidth: .infinity)
                .padding(.vertical, GentleTheme.Spacing.md + 2)
                .padding(.horizontal, GentleTheme.Spacing.md)
                .background(viewModel.isListening ? GentleTheme.primary : GentleTheme.sky.opacity(0.4))
                .foregroundStyle(viewModel.isListening ? GentleTheme.onAccent : GentleTheme.textPrimary)
                .overlay {
                    RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous)
                        .stroke(viewModel.isListening ? Color.clear : GentleTheme.outline, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.isListening ? "Stop voice capture" : "Start voice capture")
    }

    private var aiButton: some View {
        Button {
            organizeWithAI()
        } label: {
            HStack(spacing: GentleTheme.Spacing.sm) {
                if isOrganizingWithAI {
                    ProgressView().tint(GentleTheme.textPrimary)
                } else {
                    Image(systemName: "sparkles")
                        .imageScale(.medium)
                }
                Text(isOrganizingWithAI ? "Organizing..." : "Organize with AI")
            }
            .font(GentleTheme.Typography.button)
            .frame(maxWidth: .infinity)
            .padding(.vertical, GentleTheme.Spacing.md + 2)
            .padding(.horizontal, GentleTheme.Spacing.md)
            .background(canOrganizeWithAI ? GentleTheme.lilac.opacity(0.4) : GentleTheme.field)
            .foregroundStyle(canOrganizeWithAI ? GentleTheme.textPrimary : GentleTheme.textSecondary)
            .overlay {
                RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous)
                    .stroke(GentleTheme.outline, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canOrganizeWithAI || isOrganizingWithAI)
        .accessibilityLabel("Organize with AI")
    }

    private var chipsSection: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
            GentleSectionHeader(
                title: "Optional chips",
                subtitle: "Skip these if they slow you down."
            )
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: GentleTheme.Spacing.sm)],
                spacing: GentleTheme.Spacing.sm
            ) {
                ForEach(QuickCaptureChip.defaults) { chip in
                    Button {
                        viewModel.toggle(chip)
                    } label: {
                        GentleChip(
                            title: chip.title,
                            tint: tint(for: chip),
                            isSelected: viewModel.selectedChips.contains(chip)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var saveBar: some View {
        VStack(spacing: GentleTheme.Spacing.sm) {
            GentleButton(
                title: viewModel.saveButtonTitle,
                systemImage: "tray.and.arrow.down.fill",
                role: .primary,
                isEnabled: viewModel.canSave,
                action: save
            )
        }
        .padding(.horizontal, GentleTheme.Spacing.screenHorizontal)
        .padding(.top, GentleTheme.Spacing.md)
        .padding(.bottom, GentleTheme.Spacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GentleTheme.outline)
                .frame(height: 1)
        }
    }

    // MARK: - Helpers

    private var canOrganizeWithAI: Bool {
        guard let preference = preferences.first else { return false }
        return preference.enableAIParsing && !viewModel.rawText.trimmedForStorage.isEmpty
    }

    private func save() {
        isRawTextFocused = false
        let tasks = viewModel.makeTasks()
        guard !tasks.isEmpty else { return }

        tasks.forEach(modelContext.insert)
        do {
            try modelContext.save()
            viewModel.reset()
            dismiss()
        } catch {
            viewModel.voiceMessage = error.localizedDescription
        }
    }

    private func saveAIResponse(_ response: AITaskParseResponse) {
        isRawTextFocused = false
        let source = viewModel.source
        let createdAt = Date()
        let items = response.tasks.map { $0.makeTaskItem(source: source, createdAt: createdAt) }
        guard !items.isEmpty else { return }

        items.forEach(modelContext.insert)
        do {
            try modelContext.save()
            print("Gentle Day AI saved task count: \(items.count)")
            viewModel.reset()
            dismiss()
        } catch {
            aiMessage = error.localizedDescription
        }
    }

    private func toggleVoiceCapture() {
        isRawTextFocused = false
        if viewModel.isListening {
            stopVoiceCaptureAndShowPreview()
        } else {
            Task {
                await viewModel.startVoiceCapture()
            }
        }
    }

    private func stopVoiceCaptureAndShowPreview() {
        isRawTextFocused = false
        Task {
            do {
                guard let response = try await viewModel.stopVoiceCaptureAndParseForPreview(
                    preferences: preferences.first,
                    existingTasks: tasks,
                    existingScheduleBlocks: blocks
                ) else {
                    return
                }

                let patchedResponse = applyQuickDetails(to: response)
                await MainActor.run {
                    aiDraft = AIParseDraft(originalText: viewModel.rawText, response: patchedResponse)
                    aiMessage = patchedResponse.friendlySummary
                }
            } catch {
                await MainActor.run {
                    aiMessage = error.localizedDescription
                }
            }
        }
    }

    private func organizeWithAI() {
        isRawTextFocused = false
        guard let preference = preferences.first else {
            aiMessage = "Settings are still loading. Please try again in a moment."
            return
        }

        guard preference.enableAIParsing else {
            aiMessage = AIParsingFeatureError.disabled.localizedDescription
            return
        }

        let rawText = viewModel.rawText.trimmedForStorage
        guard !rawText.isEmpty else { return }

        isOrganizingWithAI = true
        aiMessage = nil

        let context = AIParsingContext(
            currentDate: Date(),
            timezone: TimeZone.current.identifier,
            locale: Locale.current.identifier,
            planningDay: .today,
            planningStyle: .balancedDay,
            preferences: preference,
            existingTasks: tasks,
            existingScheduleBlocks: blocks
        )

        Task {
            do {
                let service = AIParsingServiceFactory.makeService(preferences: preference)
                let response = try await service.parseTaskCapture(rawText: rawText, context: context)
                let patchedResponse = applyQuickDetails(to: response)
                await MainActor.run {
                    isOrganizingWithAI = false
                    aiDraft = AIParseDraft(originalText: rawText, response: patchedResponse)
                    aiMessage = patchedResponse.friendlySummary
                }
            } catch {
                await MainActor.run {
                    isOrganizingWithAI = false
                    aiMessage = error.localizedDescription
                }
            }
        }
    }

    private func applyQuickDetails(to response: AITaskParseResponse) -> AITaskParseResponse {
        let selectedCategory = viewModel.selectedChips.compactMap(\.category).first
        let selectedMinutes = viewModel.selectedChips.compactMap(\.minutes).first
        let dueDate = viewModel.selectedChips.compactMap(\.dueDateOffset).min().flatMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: Date())
        }

        let patchedTasks = response.tasks.map { original in
            var task = original
            if let selectedCategory {
                task.category = selectedCategory
            }
            if let selectedMinutes {
                task.durationMinutes = selectedMinutes
            }
            if let dueDate {
                task.dueDate = dueDate
                task.startDate = dueDate
            }
            return task
        }

        return AITaskParseResponse(
            tasks: patchedTasks,
            warnings: response.warnings,
            friendlySummary: response.friendlySummary,
            needsReview: response.needsReview
        )
    }

    private func tint(for chip: QuickCaptureChip) -> Color {
        if let category = chip.category {
            return GentleTheme.color(for: category)
        }
        if chip.minutes != nil {
            return GentleTheme.butter
        }
        if chip.dueDateOffset != nil {
            return GentleTheme.lilac
        }
        return GentleTheme.sage
    }
}

#Preview {
    NavigationStack {
        QuickCaptureView()
    }
    .modelContainer(PersistenceController.makeModelContainer())
}
