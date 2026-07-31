import SwiftUI

/// 토큰·컴포넌트 전수 확인 화면. 이번 리디자인의 회귀 검증 수단이다.
/// Xcode Canvas 에서 Dynamic Type 을 xxxLarge 로 올려도 깨지지 않아야 한다.
public struct DesignSystemShowcaseView: View {
    @State private var toggleOn = true
    @State private var sliderValue: Double = 0.6
    @State private var fieldText = ""
    @State private var areaText = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                verbatimTitle: "Design System",
                caption: "dark cinematic",
                leading: .back {},
                trailing: .icon(.settings, accessibilityLabel: "설정") {},
                showsDivider: true
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    section("색") { colorSwatches }
                    section("타이포") { typeSpecimens }
                    section("버튼") { buttons }
                    section("태그") { tags }
                    section("리스트 행") { listRows }
                    section("카드 · 안내") { cards }
                    section("상태") { states }
                    section("입력") { inputs }
                    section("썸네일") { thumbs }
                    section("캔버스") { canvas }
                    section("아이콘") { icons }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .chalNaScreen()
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title)
                .font(ChalNaTypography.title)
                .foregroundColor(ChalNaColor.textPrimary)
            content()
        }
    }

    private var colorSwatches: some View {
        let entries: [(String, Color)] = [
            ("bg", ChalNaColor.bg), ("surface", ChalNaColor.surface),
            ("surfaceRaised", ChalNaColor.surfaceRaised), ("canvas", ChalNaColor.canvas),
            ("border", ChalNaColor.border), ("borderStrong", ChalNaColor.borderStrong),
            ("textPrimary", ChalNaColor.textPrimary), ("textSecondary", ChalNaColor.textSecondary),
            ("textTertiary", ChalNaColor.textTertiary), ("accent", ChalNaColor.accent),
            ("accentFill", ChalNaColor.accentFill), ("accentPressed", ChalNaColor.accentPressed),
            ("danger", ChalNaColor.danger),
            ("brandDeep", ChalNaColor.brandDeep),
        ]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(entries, id: \.0) { name, color in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
                        .fill(color)
                        .frame(height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: ChalNaRadius.xs, style: .continuous)
                                .strokeBorder(ChalNaColor.border, lineWidth: 1)
                        )
                    Text(verbatim: name)
                        .font(ChalNaTypography.caption)
                        .foregroundColor(ChalNaColor.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var typeSpecimens: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "display — 찰나의 순간").font(ChalNaTypography.display)
            Text(verbatim: "title — 최근 필름").font(ChalNaTypography.title)
            Text(verbatim: "headline — 제주도, 우리의 봄").font(ChalNaTypography.headline)
            Text(verbatim: "body — Live Photo와 짧은 영상을 이어 붙여요").font(ChalNaTypography.body)
            Text(verbatim: "label — 8 클립 · Live 5").font(ChalNaTypography.label)
            Text(verbatim: "caption — 클립을 탭해 편집").font(ChalNaTypography.caption)
            Text(verbatim: "mono — 00:12 / 01:40").font(ChalNaTypography.mono())
            Text(verbatim: "keris — 찰나").font(ChalNaTypography.keris(28))
        }
        .foregroundColor(ChalNaColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button("primary · lg") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
            Button("secondary · lg") {}.buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
            HStack(spacing: 10) {
                Button("ghost") {}.buttonStyle(.chalNaGhost)
                Button("삭제") {}.buttonStyle(.chalNa(.ghost, destructive: true))
                Button("md") {}.buttonStyle(.chalNa(.secondary, size: .md))
                Button("sm") {}.buttonStyle(.chalNa(.secondary, size: .sm))
            }
            Button("disabled") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true)).disabled(true)
        }
    }

    private var tags: some View {
        HStack(spacing: 8) {
            ChalNaTag("LIVE", variant: .live)
            ChalNaTag("VIDEO", variant: .video, icon: .video)
            ChalNaTag("8 CLIPS", variant: .neutral)
            ChalNaTag("선택됨", variant: .accent, icon: .check)
            Spacer(minLength: 0)
        }
    }

    private var listRows: some View {
        ChalNaCard(padding: 0) {
            VStack(spacing: 0) {
                ChalNaListRow.navigate(title: "라벨", subtitle: "영상에 표시되는 시각·날짜 라벨") {}
                ChalNaListDivider()
                ChalNaListRow.navigate(title: "위치", value: "가운데 아래") {}
                ChalNaListDivider()
                ChalNaListRow.toggle(title: "시각 표시", isOn: toggleOn) { toggleOn = $0 }
                ChalNaListDivider()
                ChalNaListRow.slider(
                    title: "투명도",
                    value: sliderValue,
                    trailingText: "\(Int(sliderValue * 100))%"
                ) { sliderValue = $0 }
                ChalNaListDivider()
                ChalNaListRow.check(verbatimTitle: "한국어", isChecked: true) {}
                ChalNaListDivider()
                ChalNaListRow.navigate(title: "비활성 행", value: "off", enabled: false) {}
            }
        }
    }

    private var cards: some View {
        VStack(spacing: 12) {
            ChalNaCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: "제주도, 우리의 봄")
                        .font(ChalNaTypography.headline)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Text(verbatim: "8 클립 · 01:40")
                        .font(ChalNaTypography.label)
                        .foregroundColor(ChalNaColor.textSecondary)
                }
            }
            ChalNaNotice(
                title: "영상 파일을 찾을 수 없어요",
                message: "앱을 다시 설치하셨거나 파일이 삭제되었어요."
            )
        }
    }

    private var states: some View {
        VStack(alignment: .leading, spacing: 16) {
            ChalNaProgressBar(progress: 0.62)
            ChalNaToast(message: "사진 보관함에 저장했어요")
            ChalNaEmptyState(
                title: "아직 만든 필름이 없어요",
                message: "첫 Vlog를 시작해 보세요.",
                actionTitle: "시작하기"
            ) {}
        }
    }

    private var inputs: some View {
        VStack(spacing: 12) {
            ChalNaTextField(label: "필름 제목", placeholder: "예: 제주도, 우리의 봄",
                            helper: "비워두면 자동으로 채워져요.", text: $fieldText)
            ChalNaTextArea(placeholder: "불편한 점이나 제안을 적어주세요.", minHeight: 100, text: $areaText)
        }
    }

    private var thumbs: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array([MediaThumbState.normal, .selected, .playing, .lifted, .ghost, .dimmed].enumerated()),
                    id: \.offset) { _, state in
                MediaThumb(state: state, size: CGSize(width: 44, height: 78)) {
                    LinearGradient(colors: [ChalNaColor.accentFill, ChalNaColor.canvas],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var canvas: some View {
        ChalNaCanvas { box in
            LinearGradient(colors: [ChalNaColor.brandDeep, ChalNaColor.canvas],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: box.width, height: box.height)
        } overlay: { _ in
            ChalNaTag("3 / 8", variant: .neutral)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(12)
        }
        .frame(height: 220)
    }

    private var icons: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 18) {
            ForEach(ChalNaIconKind.allCases, id: \.self) { kind in
                VStack(spacing: 6) {
                    ChalNaIcon(kind, size: 22)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Text(verbatim: kind.rawValue)
                        .font(ChalNaTypography.caption)
                        .foregroundColor(ChalNaColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}

#Preview("Showcase") {
    DesignSystemShowcaseView()
}

#Preview("Showcase · xxxLarge") {
    DesignSystemShowcaseView()
        .environment(\.dynamicTypeSize, .xxxLarge)
}
