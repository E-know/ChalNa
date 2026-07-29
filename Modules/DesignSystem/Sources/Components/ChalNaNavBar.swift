import SwiftUI

/// 시스템 네비게이션 바를 숨긴 화면용 커스텀 헤더.
///
/// 좌·우 슬롯이 **고정 56pt** 라 타이틀이 물리적으로 액션 영역을 침범할 수 없다.
/// (구 `ChalNaNavigationBar` 는 타이틀을 ZStack 오버레이로 얹어 폭 제한이 없었고,
///  Timeline 의 사용자 입력 제목이 길면 back 버튼과 겹쳤다.)
///
/// 근거: `docs/superpowers/specs/2026-07-28-app-redesign-design.md` §5.1
public struct ChalNaNavBar: View {

    /// 좌·우 슬롯 **최소** 폭 = 44pt 액션 + 좌우 6pt 여백.
    ///
    /// 고정폭이 아니라 최소폭이다. `.text("완료")` 같은 텍스트 액션은 Dynamic Type 확대 시
    /// 56pt 를 넘길 수 있고(headline 17pt 에서 "Done" ≈ 38pt + 좌우 8pt 패딩 = 54pt,
    /// accessibility1 에서는 여유가 사라진다), 고정폭이면 그 글자가 잘린다.
    /// 최소폭으로 두면 슬롯이 필요한 만큼 늘어나 타이틀을 밀어낸다 —
    /// **타이틀이 살짝 비대칭이 되는 것이 글자가 잘리는 것보다 낫다.**
    /// 겹침 방지(감사 #20)는 HStack 이 공간을 배분하는 것으로 이미 보장된다.
    private static let slot: CGFloat = 56
    public static let height: CGFloat = 52

    private let titleText: Text
    private let caption: String?
    private let leading: ChalNaNavAction
    private let trailing: ChalNaNavAction
    private let showsDivider: Bool

    public init(
        title: LocalizedStringKey,
        caption: String? = nil,
        leading: ChalNaNavAction = .empty,
        trailing: ChalNaNavAction = .empty,
        showsDivider: Bool = false
    ) {
        self.titleText = Text(title)
        self.caption = caption
        self.leading = leading
        self.trailing = trailing
        self.showsDivider = showsDivider
    }

    /// 로컬라이즈하지 않는 타이틀(브랜드명·사용자 입력 제목)용.
    public init(
        verbatimTitle: String,
        caption: String? = nil,
        leading: ChalNaNavAction = .empty,
        trailing: ChalNaNavAction = .empty,
        showsDivider: Bool = false
    ) {
        self.titleText = Text(verbatim: verbatimTitle)
        self.caption = caption
        self.leading = leading
        self.trailing = trailing
        self.showsDivider = showsDivider
    }

    public var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(minWidth: Self.slot, alignment: .leading)

            VStack(spacing: 1) {
                titleText
                    .font(ChalNaTypography.headline)
                    .tracking(ChalNaTypography.Tracking.title)
                    .foregroundColor(ChalNaColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let caption {
                    Text(verbatim: caption)
                        .font(ChalNaTypography.caption)
                        .foregroundColor(ChalNaColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity)

            trailing
                .frame(minWidth: Self.slot, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .frame(minHeight: Self.height)
        .frame(maxWidth: .infinity)
        .background(ChalNaColor.bg.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(ChalNaColor.border)
                    .frame(height: 1)
            }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ChalNaNavBar(title: "설정", leading: .back {})
        ChalNaNavBar(
            verbatimTitle: "제주도에서 보낸 아주 긴 제목의 어느 봄날 기록",
            caption: "8 클립 · 01:40",
            leading: .back {},
            trailing: .text("저장") {},
            showsDivider: true
        )
        ChalNaNavBar(
            verbatimTitle: "ChalNa",
            trailing: .icon(.settings, accessibilityLabel: "설정") {}
        )
        Spacer()
    }
    .background(ChalNaColor.bg)
}
