import SwiftUI

struct GentleScrollView<Content: View>: View {
    var showsIndicators: Bool
    var spacing: CGFloat
    var alignment: HorizontalAlignment
    var frameAlignment: Alignment
    var horizontalPadding: CGFloat
    var topPadding: CGFloat
    var bottomPadding: CGFloat
    var content: Content

    init(
        showsIndicators: Bool = false,
        spacing: CGFloat = 24,
        alignment: HorizontalAlignment = .leading,
        frameAlignment: Alignment = .leading,
        horizontalPadding: CGFloat = GentleLayout.pageHorizontalPadding,
        topPadding: CGFloat = GentleLayout.pageTopPadding,
        bottomPadding: CGFloat = GentleLayout.scrollBottomReserve,
        @ViewBuilder content: () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.spacing = spacing
        self.alignment = alignment
        self.frameAlignment = frameAlignment
        self.horizontalPadding = horizontalPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            VStack(alignment: alignment, spacing: spacing) {
                content
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
    }
}
