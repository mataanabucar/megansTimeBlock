import SwiftUI

struct AIParsePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let originalText: String
    let response: AITaskParseResponse
    let onSave: () -> Void
    let onEditFirst: () -> Void
    let onUseRawText: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GentleTheme.Spacing.lg) {
                    GentleSectionHeader(
                        title: "AI Preview",
                        subtitle: "Review what Gentle Day understood before saving."
                    )

                    originalCard

                    LazyVStack(spacing: GentleTheme.Spacing.md) {
                        ForEach(response.tasks) { task in
                            PreviewTaskCard(task: task)
                        }
                    }

                    if !response.warnings.isEmpty {
                        warningsCard
                    }
                }
                .padding(GentleTheme.Spacing.screenHorizontal)
            }
            .gentleBackground()
            .navigationTitle("AI Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(GentleTheme.primary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
        }
    }

    // MARK: - Sections

    private var originalCard: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.sm) {
            Text("ORIGINAL")
                .font(GentleTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(GentleTheme.textSecondary)
            Text(originalText)
                .font(GentleTheme.Typography.body)
                .foregroundStyle(GentleTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .gentleCardStyle()
    }

    private var warningsCard: some View {
        VStack(alignment: .leading, spacing: GentleTheme.Spacing.sm) {
            HStack(spacing: GentleTheme.Spacing.sm) {
                GentleIconBadge(systemName: "exclamationmark.triangle.fill", tint: GentleTheme.butter, size: .small)
                Text("Warnings")
                    .font(GentleTheme.Typography.headline)
                    .foregroundStyle(GentleTheme.textPrimary)
            }
            ForEach(response.warnings) { warning in
                Text(warning.message)
                    .font(GentleTheme.Typography.subheadline)
                    .foregroundStyle(GentleTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .gentleCardStyle()
    }

    private var bottomBar: some View {
        VStack(spacing: GentleTheme.Spacing.sm) {
            GentleButton(
                title: saveButtonTitle,
                systemImage: "tray.and.arrow.down.fill",
                role: .primary,
                action: {
                    onSave()
                    dismiss()
                }
            )

            HStack(spacing: GentleTheme.Spacing.sm) {
                GentleButton(title: "Edit First", role: .secondary, action: {
                    onEditFirst()
                    dismiss()
                })
                GentleButton(title: "Use Raw Text", role: .secondary, action: {
                    onUseRawText()
                    dismiss()
                })
            }
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

    private var saveButtonTitle: String {
        response.tasks.count > 1 ? "Save \(response.tasks.count) to Inbox" : "Save to Inbox"
    }
}

// MARK: - Preview task card

/// One task as it appears in AI Preview. Hierarchical, plain-text metadata —
/// no fixed-width chips that can fragment words. Reads cleanly on iPhone SE
/// and at .xxxLarge Dynamic Type.
private struct PreviewTaskCard: View {
    let task: AITaskCandidate

    var body: some View {
        HStack(alignment: .top, spacing: GentleTheme.Spacing.md) {
            GentleIconBadge(
                systemName: GentleTaskCard.icon(for: task.category),
                tint: GentleTheme.color(for: task.category),
                size: .medium
            )

            VStack(alignment: .leading, spacing: GentleTheme.Spacing.sm) {
                Text(task.title)
                    .font(GentleTheme.Typography.headline)
                    .foregroundStyle(GentleTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)

                PreviewMetadataRow(task: task)

                if let notes = task.notes?.nilIfBlank {
                    Text(notes)
                        .font(GentleTheme.Typography.subheadline)
                        .foregroundStyle(GentleTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                }

                if task.needsReviewCallout {
                    PreviewReviewCallout(message: calloutMessage(for: task))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(GentleTheme.Spacing.cardPadding)
        .background(GentleTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous)
                .stroke(GentleTheme.outline, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.card, style: .continuous))
        .shadow(
            color: GentleTheme.Shadow.cardColor,
            radius: GentleTheme.Shadow.cardRadius,
            x: 0,
            y: GentleTheme.Shadow.cardYOffset
        )
        .accessibilityElement(children: .combine)
    }

    private func calloutMessage(for task: AITaskCandidate) -> String {
        if task.clarificationNeeded {
            return "This one may want a quick review before saving."
        }
        return "AI confidence is lower here — give it a glance."
    }
}

/// Hierarchical metadata. All plain Text rendered as natural sentences so
/// SwiftUI wraps them by word, not by character. Adapts to Dynamic Type.
///
/// Layout:
///   Line 1 (primary):   "Tomorrow evening"          — when
///   Line 2 (primary):   "Errand · 45 to 60 min"     — category · duration
///   Line 3 (secondary): "Normal energy · May need review"  — only when extra
private struct PreviewMetadataRow: View {
    let task: AITaskCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1 — schedule phrase. Always present; "Anytime" if nothing
            // useful was inferred.
            Text(task.formattedScheduleText)
                .font(GentleTheme.Typography.subheadline.weight(.medium))
                .foregroundStyle(GentleTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)

            // Line 2 — category · duration. The middle dot is preserved by
            // SwiftUI's word-aware wrapping (it never splits "5 to 10 min"
            // into "5 to" / "10 min" because of break opportunities, but the
            // Text view will wrap on word boundaries if the line overflows).
            Text("\(task.formattedCategoryText) · \(task.formattedDurationText)")
                .font(GentleTheme.Typography.caption)
                .foregroundStyle(GentleTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)

            // Line 3 — secondary details. Only render if there is something
            // meaningful: an energy hint OR a confidence note worth showing.
            // We deliberately suppress "Looks good" so the card stays calm.
            if let secondary = secondaryLine {
                Text(secondary)
                    .font(GentleTheme.Typography.caption)
                    .foregroundStyle(GentleTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
            }
        }
    }

    private var secondaryLine: String? {
        var pieces: [String] = []
        if let energy = task.formattedEnergyText {
            pieces.append(energy)
        }
        // Only surface the confidence/review text when it adds information.
        if task.needsReviewCallout {
            // The callout banner already shouts about review. Don't repeat it
            // here — keep the secondary line subtle.
        } else if task.confidence < 0.85 && !pieces.isEmpty {
            // Quietly note middling confidence without being noisy. Skip when
            // we have nothing else to pair with — confidence alone reads weird.
            pieces.append("AI confidence \(Int((task.confidence * 100).rounded()))%")
        }
        return pieces.isEmpty ? nil : pieces.joined(separator: " · ")
    }
}

/// Soft, calm warning banner for tasks that the AI flagged for review.
/// Uses peach for clarification-needed, lavender for low-confidence.
private struct PreviewReviewCallout: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: GentleTheme.Spacing.sm) {
            Image(systemName: "questionmark.circle.fill")
                .imageScale(.small)
                .foregroundStyle(GentleTheme.primaryDark)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(message)
                .font(GentleTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(GentleTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
            Spacer(minLength: 0)
        }
        .padding(GentleTheme.Spacing.sm + 2)
        .background(GentleTheme.peach.opacity(0.30))
        .overlay {
            RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous)
                .stroke(GentleTheme.peach.opacity(0.55), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
    }
}

#Preview("AI Preview — variety") {
    AIParsePreviewView(
        originalText: "Take out trash tomorrow evening, give child a bath in the afternoon, go grocery shopping, spend personal time at the park in the early evening, and have dinner ready by six.",
        response: AITaskParseResponse(
            tasks: [
                AITaskCandidate(
                    rawText: "Take out trash tomorrow evening",
                    title: "Take out trash",
                    notes: nil,
                    dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                    startDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                    startTime: nil,
                    durationMinutes: 8,
                    durationLowerMinutes: 5,
                    durationUpperMinutes: 10,
                    priority: .normal,
                    category: .home,
                    reminderPreference: .gentle,
                    recurrence: nil,
                    confidence: 0.87,
                    clarificationNeeded: false,
                    tinyStep: "Bag the bin first.",
                    shrinkOptions: [],
                    flexibleWindow: "Evening",
                    energyLevel: .low
                ),
                AITaskCandidate(
                    rawText: "Go grocery shopping",
                    title: "Go grocery shopping",
                    notes: nil,
                    dueDate: nil,
                    startDate: nil,
                    startTime: nil,
                    durationMinutes: 53,
                    durationLowerMinutes: 45,
                    durationUpperMinutes: 60,
                    priority: .normal,
                    category: .errand,
                    reminderPreference: .gentle,
                    recurrence: nil,
                    confidence: 0.72,
                    clarificationNeeded: false,
                    tinyStep: nil,
                    shrinkOptions: [],
                    flexibleWindow: nil,
                    energyLevel: .medium
                ),
                AITaskCandidate(
                    rawText: "Have dinner ready by six",
                    title: "Have dinner ready",
                    notes: nil,
                    dueDate: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()),
                    startDate: Date(),
                    startTime: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()),
                    durationMinutes: 45,
                    durationLowerMinutes: 30,
                    durationUpperMinutes: 60,
                    priority: .important,
                    category: .meals,
                    reminderPreference: .gentle,
                    recurrence: nil,
                    confidence: 0.5,
                    clarificationNeeded: true,
                    tinyStep: nil,
                    shrinkOptions: [],
                    flexibleWindow: nil,
                    energyLevel: .medium
                )
            ],
            warnings: [],
            friendlySummary: "I organized 3 tasks for review.",
            needsReview: true
        ),
        onSave: {},
        onEditFirst: {},
        onUseRawText: {}
    )
}
