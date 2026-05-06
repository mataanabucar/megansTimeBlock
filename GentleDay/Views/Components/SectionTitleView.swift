import SwiftUI

struct SectionTitleView: View {
    var title: String
    var subtitle: String? = nil
    var trailingTitle: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.navy)

                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if let trailingTitle, let trailingAction {
                Button(trailingTitle, action: trailingAction)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.lavenderDeep)
                    .buttonStyle(.plain)
            }
        }
    }
}

struct GentlePageHeader: View {
    var eyebrow: String? = nil
    var title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var centered: Bool = false
    var trailingSystemImage: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 7) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(AppColors.lavender)
                    .padding(.bottom, 2)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: centered ? .center : .leading, spacing: 4) {
                    if let eyebrow {
                        Text(eyebrow)
                            .font(AppTypography.callout.weight(.medium))
                            .foregroundStyle(AppColors.lavenderDeep)
                    }

                    Text(title)
                        .font(AppTypography.pageTitle)
                        .foregroundStyle(AppColors.navy)
                        .multilineTextAlignment(centered ? .center : .leading)
                        .lineSpacing(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.mutedText)
                            .multilineTextAlignment(centered ? .center : .leading)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)

                if let trailingSystemImage, let trailingAction {
                    SoftIconButton(systemImage: trailingSystemImage, action: trailingAction)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}
