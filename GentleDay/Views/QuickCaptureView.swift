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
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What do you need to do?")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(GentleTheme.ink)
                    Text("Messy is fine. Save it first; sort it later.")
                        .font(.body)
                        .foregroundStyle(GentleTheme.mutedInk)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $viewModel.rawText)
                        .font(.title3)
                        .foregroundStyle(GentleTheme.ink)
                        .tint(GentleTheme.sky)
                        .focused($isRawTextFocused)
                        .frame(minHeight: 170)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(GentleTheme.field)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(viewModel.isListening ? GentleTheme.sky.opacity(0.65) : GentleTheme.outline)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            if viewModel.rawText.isEmpty {
                                Text("Type the brain dump here...")
                                    .font(.title3)
                                    .foregroundStyle(GentleTheme.mutedInk.opacity(0.82))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 20)
                                    .allowsHitTesting(false)
                            }
                        }

                    Button {
                        toggleVoiceCapture()
                    } label: {
                        Label(viewModel.voiceButtonTitle, systemImage: viewModel.voiceButtonSystemImage)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                viewModel.isListening ? GentleTheme.sage : GentleTheme.sky.opacity(0.22)
                            )
                            .foregroundStyle(viewModel.isListening ? GentleTheme.onAccent : GentleTheme.ink)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(viewModel.isListening ? Color.clear : GentleTheme.outline)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if let message = viewModel.voiceMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(GentleTheme.mutedInk)
                    }

                    Button {
                        organizeWithAI()
                    } label: {
                        Label(isOrganizingWithAI ? "Organizing..." : "Organize with AI", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(canOrganizeWithAI ? GentleTheme.sky.opacity(0.22) : GentleTheme.field)
                            .foregroundStyle(canOrganizeWithAI ? GentleTheme.ink : GentleTheme.mutedInk)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(GentleTheme.outline)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canOrganizeWithAI || isOrganizingWithAI)

                    if let aiMessage {
                        Text(aiMessage)
                            .font(.footnote)
                            .foregroundStyle(GentleTheme.mutedInk)
                    }
                }
                .gentleCardStyle()

                GentleSectionHeader(title: "Optional chips", subtitle: "Skip these if they slow you down.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(QuickCaptureChip.defaults) { chip in
                        Button {
                            viewModel.toggle(chip)
                        } label: {
                            GentlePill(
                                title: chip.title,
                                tint: tint(for: chip),
                                isSelected: viewModel.selectedChips.contains(chip)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                GentlePrimaryButton(title: viewModel.saveButtonTitle, systemImage: "tray.and.arrow.down.fill") {
                    save()
                }
                .disabled(!viewModel.canSave)
                .opacity(viewModel.canSave ? 1 : 0.45)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .gentleBackground()
        .navigationTitle("Quick Capture")
        .navigationBarTitleDisplayMode(.inline)
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
        return GentleTheme.sage
    }
}

#Preview {
    NavigationStack {
        QuickCaptureView()
    }
    .modelContainer(PersistenceController.makeModelContainer())
}
