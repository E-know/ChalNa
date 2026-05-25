import SwiftUI

/// Danawa DDS Mobile 팝업/바텀시트 컨테이너.
/// SwiftUI `.sheet(...)` / `.fullScreenCover(...)` 내부에서 그리드/시트 모서리를 일관되게 잡는 용도.
public struct MomentsBottomSheet<Content: View>: View {
    public let title: String?
    public let subtitle: String?
    public let showsGrabber: Bool
    public let content: () -> Content

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        showsGrabber: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsGrabber = showsGrabber
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MomentsSpacing.md) {
            if showsGrabber {
                Capsule()
                    .fill(MomentsColor.Gray.g200)
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, MomentsSpacing.xs)
            }

            if let title {
                Text(title)
                    .font(MomentsTypography.title(MomentsTypography.Size.h1))
                    .foregroundColor(MomentsColor.ink)
            }

            if let subtitle {
                Text(subtitle)
                    .font(MomentsTypography.krBody(MomentsTypography.Size.body2))
                    .foregroundColor(MomentsColor.taupe)
            }

            content()
        }
        .padding(.horizontal, MomentsSpacing.lg)
        .padding(.bottom, MomentsSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: MomentsRadius.sheet,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: MomentsRadius.sheet,
                style: .continuous
            )
            .fill(Color.white)
        )
        .momentsShadow(MomentsShadow.lg)
    }
}

#Preview {
    MomentsBottomSheet(
        title: "내보내기 준비됨",
        subtitle: "Vlog가 저장되었어요. 공유하거나 한 번 더 확인하세요."
    ) {
        VStack(spacing: MomentsSpacing.sm) {
            Button("공유하기") {}.buttonStyle(.moments(.filled, size: .lg, fillWidth: true))
            Button("나중에") {}.buttonStyle(.moments(.standardOutlined, size: .lg, fillWidth: true))
        }
    }
    .padding(MomentsSpacing.lg)
    .background(MomentsColor.ivory)
}
