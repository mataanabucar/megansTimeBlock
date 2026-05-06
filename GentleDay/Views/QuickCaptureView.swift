import SwiftData
import SwiftUI

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = QuickCaptureViewModel()

    private var visibleChips: [QuickCaptureChip] {
        let titles = ["Today", "This Week", "Home", "Errand", "15 min", "30 min", "1 hour"]
        return titles.compactMap { title in
            QuickCaptureChip.defaults.first { $0.title == title }
        }
    }

    var body: some View {
        GentleScrollView(
            spacing: 22,
            alignment: .center,
            frameAlignment: .center,
            topPadding: 14,
            bottomPadding: GentleLayout.fixedBottomActionReserve
        ) {
            topControls

            VStack(spacing: 9) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(AppColors.sky.opacity(0.55))
                    .overlay(alignment: .topLeading) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.butter)
                            .offset(x: -14, y: -4)
                    }

                Text("What do you\nneed to do?")
                    .font(AppTypography.display(size: 29))
                    .foregroundStyle(AppColors.navy)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)

                Text("Capture it all. We'll help sort it.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.mutedText)
            }
            .padding(.top, 4)

            captureEditor
            quickDetails
            voiceButton
        }
        .gentleBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                GentlePrimaryButton(title: viewModel.saveButtonTitle, systemImage: nil) {
                    save()
                }
                .disabled(!viewModel.canSave)
                .opacity(viewModel.canSave ? 1 : 0.48)
                .padding(.horizontal, GentleLayout.pageHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .background(AppColors.background.opacity(0.94))
        }
        .onDisappear {
            viewModel.stopVoiceCapture()
        }
        .onChange(of: viewModel.voiceAutoSaveRequestID) { _, requestID in
            guard requestID != nil else { return }
            save()
        }
    }

    private var topControls: some View {
        HStack {
            SoftIconButton(systemImage: "chevron.left") {
                dismiss()
            }

            Spacer()

            SoftIconButton(systemImage: "xmark") {
                dismiss()
            }
        }
    }

    private var captureEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $viewModel.rawText)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppColors.navy)
                .tint(AppColors.lavenderDeep)
                .scrollContentBackground(.hidden)
                .padding(14)
                .frame(minHeight: 140)

            if viewModel.rawText.isEmpty {
                Text("Pick up groceries after daycare,\ncall dentist, clean kitchen tonight,\nreturn package")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppColors.navy.opacity(0.76))
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 22)
                    .allowsHitTesting(false)
            }
        }
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(viewModel.isListening ? AppColors.lavender : AppColors.lavender.opacity(0.62), lineWidth: 1.2)
        }
        .shadow(color: DesignTokens.cardShadow.color, radius: 12, x: 0, y: 8)
    }

    private var quickDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick add details")
                .font(AppTypography.callout.weight(.medium))
                .foregroundStyle(AppColors.slate)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 9),
                    GridItem(.flexible(), spacing: 9)
                ],
                spacing: 9
            ) {
                ForEach(visibleChips) { chip in
                    Button {
                        viewModel.toggle(chip)
                    } label: {
                        PillChip(
                            title: chip.title,
                            systemImage: icon(for: chip),
                            tint: tint(for: chip),
                            background: background(for: chip),
                            isSelected: viewModel.selectedChips.contains(chip),
                            fillsWidth: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var voiceButton: some View {
        VStack(spacing: 9) {
            Button {
                Task {
                    await viewModel.toggleVoiceCapture()
                }
            } label: {
                Image(systemName: viewModel.voiceButtonSystemImage)
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(Color.white)
                    .frame(width: 64, height: 64)
                    .background(AppColors.primaryGradient)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.72), lineWidth: 3)
                    }
                    .shadow(color: AppColors.lavender.opacity(0.26), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)

            Text(viewModel.isListening ? "Listening..." : "Tap to speak")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.mutedText)

            if let message = viewModel.voiceMessage {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.mutedText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
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

    private func icon(for chip: QuickCaptureChip) -> String? {
        if let category = chip.category {
            return GentleTheme.symbol(for: category)
        }
        if chip.minutes != nil {
            return "clock"
        }
        return "calendar"
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

    private func background(for chip: QuickCaptureChip) -> Color {
        if let category = chip.category {
            return GentleTheme.softColor(for: category)
        }
        if chip.minutes != nil {
            return AppColors.skySoft
        }
        return AppColors.lavenderSoft
    }
}

#Preview {
    NavigationStack {
        QuickCaptureView()
    }
    .modelContainer(PersistenceController.makeModelContainer())
}
