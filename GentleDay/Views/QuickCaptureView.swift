import SwiftData
import SwiftUI

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = QuickCaptureViewModel()

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
                        Task {
                            await viewModel.toggleVoiceCapture()
                        }
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
        .gentleBackground()
        .navigationTitle("Quick Capture")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.stopVoiceCapture()
        }
        .onChange(of: viewModel.voiceAutoSaveRequestID) { _, requestID in
            guard requestID != nil else { return }
            save()
        }
    }

    private func save() {
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
