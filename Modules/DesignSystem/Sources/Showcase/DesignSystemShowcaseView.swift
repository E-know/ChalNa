import SwiftUI

/// Danawa DDS Mobile v2.0 디자인 시스템 카탈로그. 토큰·컴포넌트 검증용.
public struct DesignSystemShowcaseView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 48) {
                header
                colorSection
                typographySection
                buttonSection
                buttonT7Section // TEMP(T7): 스크린샷 확인용, Task 12 재작성 때 buttonSection 에 흡수
                chipSection
                textFieldSection
                foundationSection
                navBarSection // TEMP(T6): Task 12 재작성 때 정식 구조로 흡수
                cardListRowT8Section // TEMP(T8): Task 12 재작성 때 정식 구조로 흡수
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .chalNaScreen()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ChalNa")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h1))
                .foregroundColor(ChalNaColor.Gray.g900)
            Text("Danawa DDS Mobile v2.0 — Design System")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.body2))
                .foregroundColor(ChalNaColor.Gray.g500)
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        sectionShell(title: "Color") {
            VStack(alignment: .leading, spacing: 16) {
                colorRow("Brand", swatches: [
                    ("Primary", ChalNaColor.Purple.p600, "#8B38E5"),
                    ("White",   Color.white, "#FFFFFF"),
                    ("Ivory",   ChalNaColor.Gray.g50, "#F8F8F8"),
                    ("Ink",     ChalNaColor.Gray.g900,   "#1A1A1A"),
                    ("Taupe",   ChalNaColor.Gray.g500, "#919191"),
                ])
                colorRow("Status", swatches: [
                    ("Success", ChalNaColor.success, "#06B87F"),
                    ("Danger",  ChalNaColor.danger,  "#E53B38"),
                    ("Info",    ChalNaColor.info,    "#02B8D3"),
                    ("Link",    ChalNaColor.Blue.b500,   "#2070EB"),
                ])
                colorScale("Purple", scale: [
                    ("100", ChalNaColor.Purple.p100), ("300", ChalNaColor.Purple.p300),
                    ("500", ChalNaColor.Purple.p500), ("600", ChalNaColor.Purple.p600),
                    ("800", ChalNaColor.Purple.p800),
                ])
                colorScale("Gray", scale: [
                    ("50", ChalNaColor.Gray.g50), ("100", ChalNaColor.Gray.g100),
                    ("300", ChalNaColor.Gray.g300), ("500", ChalNaColor.Gray.g500),
                    ("700", ChalNaColor.Gray.g700), ("900", ChalNaColor.Gray.g900),
                ])
            }
        }
    }

    private func colorRow(_ label: String, swatches: [(String, Color, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: .semibold))
                .foregroundColor(ChalNaColor.Gray.g500)
            HStack(spacing: 12) {
                ForEach(Array(swatches.enumerated()), id: \.offset) { _, s in
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                            .fill(s.1)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                                    .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 0.5)
                            )
                        Text(s.0)
                            .font(ChalNaTypography.krBody(ChalNaTypography.Size.caption, weight: .medium))
                            .foregroundColor(ChalNaColor.Gray.g900)
                        Text(s.2)
                            .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                            .foregroundColor(ChalNaColor.Gray.g500)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func colorScale(_ label: String, scale: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: .semibold))
                .foregroundColor(ChalNaColor.Gray.g500)
            HStack(spacing: 6) {
                ForEach(Array(scale.enumerated()), id: \.offset) { _, s in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: ChalNaRadius.film, style: .continuous)
                            .fill(s.1)
                            .frame(height: 40)
                        Text(s.0)
                            .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                            .foregroundColor(ChalNaColor.Gray.g500)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Typography

    private var typographySection: some View {
        sectionShell(title: "Typography") {
            VStack(alignment: .leading, spacing: 16) {
                typeRow("Title H1 · 24pt", font: ChalNaTypography.title(ChalNaTypography.Size.h1))
                typeRow("Big · 22pt", font: ChalNaTypography.title(ChalNaTypography.Size.big, weight: .bold))
                typeRow("Medium · 20pt", font: ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                typeRow("Header · 19pt", font: ChalNaTypography.krBody(ChalNaTypography.Size.header, weight: .regular))
                typeRow("Body · 16pt", font: ChalNaTypography.krBody(ChalNaTypography.Size.body))
                typeRow("Body2 · 15pt", font: ChalNaTypography.krBody(ChalNaTypography.Size.body2))
                typeRow("Small · 14pt", font: ChalNaTypography.krBody(ChalNaTypography.Size.small))
                typeRow("Caption · 12pt", font: ChalNaTypography.krBody(ChalNaTypography.Size.caption))
                typeRow("Mono · 14pt", font: ChalNaTypography.monoFallback(ChalNaTypography.Size.small))
            }
        }
    }

    private func typeRow(_ label: String, font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                .foregroundColor(ChalNaColor.Gray.g500)
                .frame(width: 110, alignment: .leading)
            Text("매일의 순간을 기록하다 · ChalNa")
                .font(font)
                .foregroundColor(ChalNaColor.Gray.g900)
        }
    }

    // MARK: - Button

    private var buttonSection: some View {
        sectionShell(title: "Button") {
            VStack(alignment: .leading, spacing: 16) {
                buttonRow(label: "Filled · L", variant: .filled, size: .lg)
                buttonRow(label: "Outlined · L", variant: .outlined, size: .lg)
                buttonRow(label: "Standard Filled · L", variant: .standardFilled, size: .lg)
                buttonRow(label: "Standard Outlined · L", variant: .standardOutlined, size: .lg)
                HStack(spacing: 12) {
                    Button("XL") {}.buttonStyle(.chalNa(.filled, size: .xl))
                    Button("L") {}.buttonStyle(.chalNa(.filled, size: .lg))
                    Button("M") {}.buttonStyle(.chalNa(.filled, size: .md))
                    Button("S") {}.buttonStyle(.chalNa(.filled, size: .sm))
                }
                Button("Text 버튼 →") {}.buttonStyle(.chalNaText)
            }
        }
    }

    // MARK: - Button T7 (TEMP(T7): Task 12 재작성 때 buttonSection 에 흡수)

    private var buttonT7Section: some View {
        sectionShell(title: "Button (T7)") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Button("Primary") {}.buttonStyle(.chalNa(.primary, size: .lg))
                    Button("Secondary") {}.buttonStyle(.chalNa(.secondary, size: .lg))
                    Button("Ghost") {}.buttonStyle(.chalNa(.ghost, size: .lg))
                }
                HStack(spacing: 12) {
                    Button("Secondary destructive") {}.buttonStyle(.chalNa(.secondary, size: .lg, destructive: true))
                    Button("Ghost destructive") {}.buttonStyle(.chalNa(.ghost, size: .lg, destructive: true))
                }
                HStack(spacing: 12) {
                    Button("LG") {}.buttonStyle(.chalNa(.primary, size: .lg))
                    Button("MD") {}.buttonStyle(.chalNa(.primary, size: .md))
                    Button("SM") {}.buttonStyle(.chalNa(.primary, size: .sm))
                }
                Button("비활성 Primary") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true)).disabled(true)
                // TEMP(T7 fix1): ghost pressed 색이 destructive 를 반영하는지 스와치로 증명.
                // 시뮬레이터에서 버튼을 누른 상태를 스크린샷으로 잡기 어려워, foreground(pressed:) 가
                // 실제로 반환하는 두 색(accentPressed vs dangerPressed)을 그대로 노출한다.
                HStack(spacing: 12) {
                    pressedSwatch("ghost pressed\n(normal)", color: ChalNaColor.accentPressed)
                    pressedSwatch("ghost pressed\n(destructive)", color: ChalNaColor.dangerPressed)
                }
                ChalNaBottomBar {
                    HStack(spacing: 10) {
                        Button("취소") {}.buttonStyle(.chalNa(.secondary, size: .lg, fillWidth: true))
                        Button("다음") {}.buttonStyle(.chalNa(.primary, size: .lg, fillWidth: true))
                    }
                }
            }
        }
    }

    // TEMP(T7 fix1): pressed 색 스와치 헬퍼. fix round 1 검증 후 buttonT7Section 과 함께 제거.
    private func pressedSwatch(_ label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                .fill(color)
                .frame(width: 140, height: 40)
            Text(label)
                .font(ChalNaTypography.caption)
                .foregroundColor(ChalNaColor.Gray.g500)
                .multilineTextAlignment(.center)
        }
    }

    private func buttonRow(label: String, variant: ChalNaButtonVariant, size: ChalNaButtonSize) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                .foregroundColor(ChalNaColor.Gray.g500)
            Button("샘플 라벨") {}.buttonStyle(.chalNa(variant, size: size, fillWidth: true))
        }
    }

    // MARK: - Chip

    private var chipSection: some View {
        sectionShell(title: "Chip") {
            HStack(spacing: 8) {
                ChalNaChip("LIVE", variant: .live)
                ChalNaChip("VIDEO", variant: .video, icon: .film)
                ChalNaChip("FILM", variant: .film, icon: .film)
                ChalNaChip("SELECTED", variant: .selected, icon: .check)
                ChalNaChip("+ 날짜", variant: .dashed)
            }
        }
    }

    // MARK: - TextField

    private var textFieldSection: some View {
        sectionShell(title: "TextField") {
            VStack(spacing: 16) {
                ShowcaseTextField()
            }
        }
    }

    // MARK: - Foundation

    private var foundationSection: some View {
        sectionShell(title: "Foundation") {
            VStack(alignment: .leading, spacing: 16) {
                radiusRow
                shadowRow
                spacingRow
            }
        }
    }

    private var radiusRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Radius (4pt 단위)")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: .semibold))
                .foregroundColor(ChalNaColor.Gray.g500)
            HStack(spacing: 12) {
                radiusSwatch("film 4", radius: ChalNaRadius.film)
                radiusSwatch("button 4", radius: ChalNaRadius.button)
                radiusSwatch("card 8", radius: ChalNaRadius.card)
                radiusSwatch("sheet 16", radius: ChalNaRadius.sheet)
            }
        }
    }

    private func radiusSwatch(_ label: String, radius: CGFloat) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(ChalNaColor.Purple.p100)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(ChalNaColor.Purple.p600, lineWidth: 1)
                )
                .frame(height: 56)
            Text(label)
                .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                .foregroundColor(ChalNaColor.Gray.g500)
        }
        .frame(maxWidth: .infinity)
    }

    private var shadowRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shadow (#000000 20% blur 6 표준)")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: .semibold))
                .foregroundColor(ChalNaColor.Gray.g500)
            HStack(spacing: 16) {
                shadowSwatch("sm", layers: ChalNaShadow.sm)
                shadowSwatch("md", layers: ChalNaShadow.md)
                shadowSwatch("lg", layers: ChalNaShadow.lg)
            }
        }
    }

    private func shadowSwatch(_ label: String, layers: [ChalNaShadowLayer]) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(Color.white)
                .frame(width: 80, height: 56)
                .chalNaShadow(layers)
            Text(label)
                .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                .foregroundColor(ChalNaColor.Gray.g500)
        }
    }

    private var spacingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spacing (4pt base)")
                .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: .semibold))
                .foregroundColor(ChalNaColor.Gray.g500)
            HStack(alignment: .bottom, spacing: 6) {
                spacingBar("xxs", 4)
                spacingBar("xs", 8)
                spacingBar("sm", 12)
                spacingBar("md", 16)
                spacingBar("lg", 24)
                spacingBar("xl", 32)
                spacingBar("xxl", 48)
            }
        }
    }

    private func spacingBar(_ label: String, _ value: CGFloat) -> some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(ChalNaColor.Purple.p600)
                .frame(width: 24, height: value)
            Text(label)
                .font(ChalNaTypography.monoFallback(ChalNaTypography.Size.caption))
                .foregroundColor(ChalNaColor.Gray.g500)
        }
        .frame(width: 36)
    }

    // MARK: - NavBar (TEMP(T6): Task 12 에서 정식 구조로 흡수)

    // TEMP(T6): ChalNaNavBar 는 아직 이 Showcase 의 정식 섹션이 아니다.
    // 4가지 상태를 임시로 보여준다 — 특히 3번은 감사 #20(긴 타이틀-액션 겹침) 회귀 확인용.
    private var navBarSection: some View {
        sectionShell(title: "NavBar (TEMP T6)") {
            VStack(spacing: 1) {
                ChalNaNavBar(verbatimTitle: "타이틀만")
                ChalNaNavBar(
                    verbatimTitle: "저장 완료 화면",
                    caption: "캡션 텍스트",
                    leading: .back {},
                    trailing: .text("저장") {}
                )
                ChalNaNavBar(
                    verbatimTitle: "제주도에서 보낸 아주 길고 긴 제목의 어느 봄날의 기록 전체",
                    leading: .back {},
                    trailing: .text("저장") {}
                )
                ChalNaNavBar(
                    verbatimTitle: "ChalNa",
                    trailing: .icon(.settings, accessibilityLabel: "설정") {}
                )
            }
        }
    }

    // MARK: - Card & ListRow (TEMP(T8): Task 12 재작성 때 정식 구조로 흡수)

    private var cardListRowT8Section: some View {
        sectionShell(title: "Card & ListRow (TEMP T8)") {
            ShowcaseCardListRow()
        }
    }

    // MARK: - Helpers

    private func sectionShell<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(ChalNaTypography.title(ChalNaTypography.Size.big, weight: .bold))
                    .foregroundColor(ChalNaColor.Gray.g900)
                Spacer()
                Rectangle()
                    .fill(ChalNaColor.Gray.g200)
                    .frame(height: 1)
            }
            content()
        }
    }
}

/// 단순 텍스트필드 데모용 wrapper (State 보유).
private struct ShowcaseTextField: View {
    @State private var text: String = ""
    @State private var failing: String = "30자를 넘는 값입니다."

    var body: some View {
        VStack(spacing: 16) {
            ChalNaTextField(label: "필름 제목", placeholder: "예: 제주도, 우리의 봄", helper: "비워두면 자동으로 채워져요.", text: $text)
            ChalNaTextField(label: "에러 상태", placeholder: "값을 입력하세요", errorText: "30자 이내로 입력해 주세요.", text: $failing)
        }
    }
}

/// Card·ListRow·Slider 데모용 wrapper (State 보유). TEMP(T8): Task 12 재작성 때 제거.
private struct ShowcaseCardListRow: View {
    @State private var autoPlayOn = true
    @State private var labelOn = false
    @State private var opacity: Double = 0.6
    @State private var isKorean = true
    @State private var standaloneValue: Double = 0.4

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ChalNaCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("제주도, 우리의 봄")
                        .font(ChalNaTypography.headline)
                        .foregroundColor(ChalNaColor.textPrimary)
                    Text(verbatim: "8 클립 · 01:40")
                        .font(ChalNaTypography.label)
                        .foregroundColor(ChalNaColor.textSecondary)
                }
            }

            ChalNaCard(padding: 0) {
                VStack(spacing: 0) {
                    ChalNaListRow.navigate(title: "비활성 행", value: "예시", enabled: false) {}
                    ChalNaListDivider()
                    ChalNaListRow.toggle(title: "자동 재생", isOn: autoPlayOn) { autoPlayOn = $0 }
                    ChalNaListDivider()
                    ChalNaListRow.toggleVerbatim(title: "제목 라벨 표시", isOn: labelOn) { labelOn = $0 }
                    ChalNaListDivider()
                    ChalNaListRow.slider(title: "투명도", value: opacity, trailingText: "\(Int(opacity * 100))%") { opacity = $0 }
                    ChalNaListDivider()
                    ChalNaListRow.check(verbatimTitle: "한국어", isChecked: isKorean) { isKorean.toggle() }
                }
            }

            ChalNaSlider(value: $standaloneValue)
        }
    }
}

#Preview {
    DesignSystemShowcaseView()
}
