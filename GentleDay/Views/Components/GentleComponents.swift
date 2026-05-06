import SwiftUI

struct GentleActionCard: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(GentleTheme.ink)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(GentleTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gentleCardStyle()
    }
}

struct GentleSectionHeader: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(GentleTheme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(GentleTheme.mutedInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GentlePill: View {
    var title: String
    var tint: Color = GentleTheme.sage
    var isSelected: Bool = false

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : GentleTheme.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(isSelected ? tint : tint.opacity(0.16))
            .clipShape(Capsule())
    }
}

struct GentleEmptyState: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(GentleTheme.sage)
            Text(title)
                .font(.headline)
                .foregroundStyle(GentleTheme.ink)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(GentleTheme.mutedInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .gentleCardStyle()
    }
}

struct GentlePrimaryButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "heart.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(GentleTheme.sage)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct GentleMetadataRow: View {
    var items: [String]

    var body: some View {
        HStack {
            ForEach(items.filter { !$0.isEmpty }, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GentleTheme.mutedInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(GentleTheme.background)
                    .clipShape(Capsule())
            }
        }
    }
}

