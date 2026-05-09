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
                VStack(alignment: .leading, spacing: 18) {
                    GentleSectionHeader(
                        title: "AI Preview",
                        subtitle: "Review what Gentle Day understood before saving."
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(GentleTheme.mutedInk)
                        Text(originalText)
                            .font(.body)
                            .foregroundStyle(GentleTheme.ink)
                    }
                    .gentleCardStyle()

                    ForEach(response.tasks) { task in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(task.title)
                                .font(.headline)
                                .foregroundStyle(GentleTheme.ink)

                            GentleMetadataRow(items: [
                                task.whenDescription,
                                "\(task.durationMinutes) min",
                                task.category.title,
                                task.priority.title,
                                "\(Int((task.confidence * 100).rounded()))%"
                            ])

                            if let notes = task.notes?.nilIfBlank {
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundStyle(GentleTheme.mutedInk)
                            }

                            if task.clarificationNeeded {
                                Text("This one may need a quick review before saving.")
                                    .font(.footnote)
                                    .foregroundStyle(GentleTheme.peach)
                            }
                        }
                        .gentleCardStyle()
                    }

                    if !response.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Warnings")
                                .font(.headline)
                                .foregroundStyle(GentleTheme.ink)

                            ForEach(response.warnings) { warning in
                                Text(warning.message)
                                    .font(.subheadline)
                                    .foregroundStyle(GentleTheme.mutedInk)
                            }
                        }
                        .gentleCardStyle()
                    }
                }
                .padding(20)
            }
            .gentleBackground()
            .navigationTitle("AI Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    GentlePrimaryButton(title: saveButtonTitle, systemImage: "tray.and.arrow.down.fill") {
                        onSave()
                        dismiss()
                    }

                    HStack(spacing: 10) {
                        secondaryButton("Edit First") {
                            onEditFirst()
                            dismiss()
                        }

                        secondaryButton("Use Raw Text") {
                            onUseRawText()
                            dismiss()
                        }
                    }
                }
                .padding(16)
                .background(GentleTheme.background.opacity(0.96))
            }
        }
    }

    private var saveButtonTitle: String {
        response.tasks.count > 1 ? "Save \(response.tasks.count) to Inbox" : "Save to Inbox"
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(GentleTheme.field)
                .foregroundStyle(GentleTheme.ink)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GentleTheme.outline)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
