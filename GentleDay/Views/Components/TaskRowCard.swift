import SwiftUI

struct TaskRowAction: Identifiable {
    var title: String
    var systemImage: String
    var tint: Color = AppColors.slate
    var action: () -> Void

    var id: String { title }
}

struct TaskRowCard: View {
    var title: String
    var metadata: String
    var category: TaskCategory
    var detail: String?
    var actions: [TaskRowAction] = []

    var body: some View {
        SoftCard(innerPadding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    CategoryIconBadge(category: category, size: 42)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(AppColors.navy)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(metadata)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.mutedText)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)
                }
                .padding(18)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.mutedText)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                }

                if !actions.isEmpty {
                    Divider()
                        .overlay(AppColors.softBorder.opacity(0.42))

                    HStack(spacing: 0) {
                        ForEach(actions) { item in
                            Button(action: item.action) {
                                Label(item.title, systemImage: item.systemImage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(item.tint)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                            }
                            .buttonStyle(.plain)

                            if item.id != actions.last?.id {
                                Rectangle()
                                    .fill(AppColors.softBorder.opacity(0.36))
                                    .frame(width: 1, height: 22)
                            }
                        }
                    }
                }
            }
        }
    }
}
