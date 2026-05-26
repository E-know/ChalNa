import SwiftUI

/// Danawa DDS Mobile 팝업/바텀시트 컨테이너.
/// SwiftUI `.sheet(...)` / `.fullScreenCover(...)` 내부에서 그리드/시트 모서리를 일관되게 잡는 용도.
public struct ChalNaBottomSheet<Content: View>: View {
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
        VStack(alignment: .leading, spacing: 16) {
            if showsGrabber {
                Capsule()
                    .fill(ChalNaColor.Gray.g200)
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }

            if let title {
                Text(title)
                    .font(ChalNaTypography.title(ChalNaTypography.Size.h1))
                    .foregroundColor(ChalNaColor.ink)
            }

            if let subtitle {
                Text(subtitle)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2))
                    .foregroundColor(ChalNaColor.taupe)
            }

            content()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: ChalNaRadius.sheet,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: ChalNaRadius.sheet,
                style: .continuous
            )
            .fill(Color.white)
        )
        .chalNaShadow(ChalNaShadow.lg)
    }
}

#Preview {
    ChalNaBottomSheet(
        title: "내보내기 준비됨",
        subtitle: "Vlog가 저장되었어요. 공유하거나 한 번 더 확인하세요."
    ) {
        VStack(spacing: 12) {
            Button("공유하기") {}.buttonStyle(.chalNa(.filled, size: .lg, fillWidth: true))
            Button("나중에") {}.buttonStyle(.chalNa(.standardOutlined, size: .lg, fillWidth: true))
        }
    }
    .padding(24)
    .background(ChalNaColor.ivory)
}
