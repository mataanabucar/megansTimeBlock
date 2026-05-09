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
                    parsedTasks
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

    @ViewBuilder
    private var parsedTasks: some View {
        ForEach(response.tasks) { task in
            VStack(alignment: .leading, spacing: GentleTheme.Spacing.md) {
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
                        GentleMetadataRow(items: [
                            task.whenDescription,
                            "\(task.durationMinutes) min",
                            task.category.title,
                            task.priority.title,
                            "\(Int((task.confidence * 100).rounded()))%"
                        ])
                    }
                    Spacer(minLength: 0)
                }

                if let notes = task.notes?.nilIfBlank {
                    Text(notes)
                        .font(GentleTheme.Typography.subheadline)
                        .foregroundStyle(GentleTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if task.clarificationNeeded {
                    HStack(spacing: GentleTheme.Spacing.sm) {
                        Image(systemName: "questionmark.circle.fill")
                            .imageScale(.small)
                            .foregroundStyle(GentleTheme.primary)
                        Text("This one may want a quick review before saving.")
                            .font(GentleTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(GentleTheme.textPrimary)
                        Spacer()
                    }
                    .padding(GentleTheme.Spacing.sm + 2)
                    .background(GentleTheme.peach.opacity(0.30))
                    .clipShape(RoundedRectangle(cornerRadius: GentleTheme.Radius.chip, style: .continuous))
                }
            }
            .gentleCardStyle()
        }
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
