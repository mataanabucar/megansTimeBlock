import SwiftUI

struct AIParsePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let originalText: String
    let response: AITaskParseResponse
    let onSave: () -> Void
    let onEditFirst: () -> Void
    let onUseRawText: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            GentleScrollView(spacing: 18, topPadding: 18, bottomPadding: 120) {
                GentlePageHeader(
                    title: "AI Preview",
                    subtitle: "Review what Gentle Day understood before saving.",
                    centered: false
                )

                SoftCard(background: AppColors.lavenderMist, stroke: AppColors.lavender.opacity(0.24)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.slate)

                        Text(originalText)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.navy)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let first = response.tasks.first {
                    SoftCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Understood as")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.slate)

                            PreviewDetailRow(title: "Task", value: first.cleanedTitle)
                            PreviewDetailRow(title: "When", value: first.whenDescription)
                            PreviewDetailRow(title: "Time needed", value: "\(first.estimatedMinutes) minutes")
                            PreviewDetailRow(title: "Category", value: first.category.title)
                            PreviewDetailRow(title: "Tiny step", value: first.tinyStep ?? "Do the first visible step.")
                            PreviewDetailRow(title: "Confidence", value: "\(Int((first.confidence * 100).rounded()))%")

                            if !first.shrinkOptions.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Shrink options")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.slate)

                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(first.shrinkOptions, id: \.self) { option in
                                            Text(option)
                                                .font(AppTypography.callout)
                                                .foregroundStyle(AppColors.mutedText)
                                        }
                                    }
                                }
                            }

                            if let note = first.friendlyNote?.nilIfBlank {
                                SoftCard(background: AppColors.sageSoft, stroke: AppColors.sage.opacity(0.12), innerPadding: 14) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Friendly note")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.slate)
                                        Text(note)
                                            .font(AppTypography.callout)
                                            .foregroundStyle(AppColors.navy)
                                    }
                                }
                            }
                        }
                    }
                }

                if response.tasks.count > 1 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Additional tasks")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.slate)

                        ForEach(Array(response.tasks.dropFirst()), id: \.id) { task in
                            SoftCard(innerPadding: 15) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(task.cleanedTitle)
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundStyle(AppColors.navy)
                                    Text(task.whenDescription)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.mutedText)
                                }
                            }
                        }
                    }
                }

                if !response.warnings.isEmpty {
                    SoftCard(background: AppColors.peachSoft, stroke: AppColors.peach.opacity(0.18)) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Warnings")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.slate)

                            ForEach(response.warnings) { warning in
                                Text(warning.message)
                                    .font(AppTypography.callout)
                                    .foregroundStyle(AppColors.navy)
                            }
                        }
                    }
                }
            }
            .gentleBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundStyle(AppColors.slate)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    GentlePrimaryButton(title: "Save to Inbox", systemImage: nil) {
                        onSave()
                        dismiss()
                    }

                    HStack(spacing: 10) {
                        SecondaryPreviewButton(title: "Edit First", action: {
                            onEditFirst()
                            dismiss()
                        })
                        SecondaryPreviewButton(title: "Use Raw Text Instead", action: {
                            onUseRawText()
                            dismiss()
                        })
                    }
                }
                .padding(.horizontal, GentleLayout.pageHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(AppColors.background.opacity(0.96))
            }
        }
    }
}

private struct PreviewDetailRow: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.slate)
            Text(value)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.navy)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SecondaryPreviewButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.slate)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .stroke(AppColors.softBorder.opacity(0.68), lineWidth: 0.8)
                }
        }
        .buttonStyle(.plain)
    }
}
