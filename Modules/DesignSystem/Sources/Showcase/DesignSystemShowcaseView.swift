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
                chipSection
                textFieldSection
                foundationSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(MomentsColor.cream.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Moments")
                .font(MomentsTypography.title(MomentsTypography.Size.h1))
                .foregroundColor(MomentsColor.ink)
            Text("Danawa DDS Mobile v2.0 — Design System")
                .font(MomentsTypography.krBody(MomentsTypography.Size.body2))
                .foregroundColor(MomentsColor.taupe)
        }
    }

    // MARK: - Color

    private var colorSection: some View {
        sectionShell(title: "Color") {
            VStack(alignment: .leading, spacing: 16) {
                colorRow("Brand", swatches: [
                    ("Primary", MomentsColor.coral, "#8B38E5"),
                    ("Cream",   MomentsColor.cream, "#FFFFFF"),
                    ("Ivory",   MomentsColor.ivory, "#F8F8F8"),
                    ("Ink",     MomentsColor.ink,   "#1A1A1A"),
                    ("Taupe",   MomentsColor.taupe, "#919191"),
                ])
                colorRow("Status", swatches: [
                    ("Success", MomentsColor.success, "#06B87F"),
                    ("Danger",  MomentsColor.danger,  "#E53B38"),
                    ("Info",    MomentsColor.info,    "#02B8D3"),
                    ("Link",    MomentsColor.denim,   "#2070EB"),
                ])
                colorScale("Purple", scale: [
                    ("100", MomentsColor.Purple.p100), ("300", MomentsColor.Purple.p300),
                    ("500", MomentsColor.Purple.p500), ("600", MomentsColor.Purple.p600),
                    ("800", MomentsColor.Purple.p800),
                ])
                colorScale("Gray", scale: [
                    ("50", MomentsColor.Gray.g50), ("100", MomentsColor.Gray.g100),
                    ("300", MomentsColor.Gray.g300), ("500", MomentsColor.Gray.g500),
                    ("700", MomentsColor.Gray.g700), ("900", MomentsColor.Gray.g900),
                ])
            }
        }
    }

    private func colorRow(_ label: String, swatches: [(String, Color, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(MomentsTypography.krBody(MomentsTypography.Size.small, weight: .semibold))
                .foregroundColor(MomentsColor.taupe)
            HStack(spacing: 12) {
                ForEach(Array(swatches.enumerated()), id: \.offset) { _, s in
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                            .fill(s.1)
                            .frame(height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                                    .strokeBorder(MomentsColor.Gray.g100, lineWidth: 0.5)
                            )
                        Text(s.0)
                            .font(MomentsTypography.krBody(MomentsTypography.Size.caption, weight: .medium))
                            .foregroundColor(MomentsColor.ink)
                        Text(s.2)
                            .font(MomentsTypography.monoFallback(MomentsTypography.Size.caption))
                            .foregroundColor(MomentsColor.taupe)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func colorScale(_ label: String, scale: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(MomentsTypography.krBody(MomentsTypography.Size.small, weight: .semibold))
                .foregroundColor(MomentsColor.taupe)
            HStack(spacing: 6) {
                ForEach(Array(scale.enumerated()), id: \.offset) { _, s in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: MomentsRadius.film, style: .continuous)
                            .fill(s.1)
                            .frame(height: 40)
                        Text(s.0)
                            .font(MomentsTypography.monoFallback(MomentsTypography.Size.caption))
                            .foregroundColor(MomentsColor.taupe)
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
                typeRow("Title H1 · 24pt", font: MomentsTypography.title(MomentsTypography.Size.h1))
                typeRow("Big · 22pt", font: MomentsTypography.title(MomentsTypography.Size.big, weight: .bold))
                typeRow("Medium · 20pt", font: MomentsTypography.title(MomentsTypography.Size.h2, weight: .semibold))
                typeRow("Header · 19pt", font: MomentsTypography.krBody(MomentsTypography.Size.header, weight: .regular))
                typeRow("Body · 16pt", font: MomentsTypography.krBody(MomentsTypography.Size.body))
                typeRow("Body2 · 15pt", font: MomentsTypography.krBody(MomentsTypography.Size.body2))
                typeRow("Small · 14pt", font: MomentsTypography.krBody(MomentsTypography.Size.small))
                typeRow("Caption · 12pt", font: MomentsTypography.krBody(MomentsTypography.Size.caption))
                typeRow("Mono · 14pt", font: MomentsTypography.monoFallback(MomentsTypography.Size.small))
            }
        }
    }

    private func typeRow(_ label: String, font: Font) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(MomentsTypography.monoFallback(MomentsTypography.Size.caption))
                .foregroundColor(MomentsColor.taupe)
                .frame(width: 110, alignment: .leading)
            Text("매일의 순간을 기록하다 · Moments")
                .font(font)
                .foregroundColor(MomentsColor.ink)
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
                    Button("XL") {}.buttonStyle(.moments(.filled, size: .xl))
                    Button("L") {}.buttonStyle(.moments(.filled, size: .lg))
                    Button("M") {}.buttonStyle(.moments(.filled, size: .md))
                    Button("S") {}.buttonStyle(.moments(.filled, size: .sm))
                }
                Button("Text 버튼 →") {}.buttonStyle(.momentsText)
            }
        }
    }

    private func buttonRow(label: String, variant: MomentsButtonVariant, size: MomentsButtonSize) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(MomentsTypography.monoFallback(MomentsTypography.Size.caption))
                .foregroundColor(MomentsColor.taupe)
            Button("샘플 라벨") {}.buttonStyle(.moments(variant, size: size, fillWidth: true))
        }
    }

    // MARK: - Chip

    private var chipSection: some View {
        sectionShell(title: "Chip") {
            HStack(spacing: 8) {
                MomentsChip("LIVE", variant: .live)
                MomentsChip("VIDEO", variant: .video, icon: .film)
                MomentsChip("FILM", variant: .film, icon: .film)
                MomentsChip("SELECTED", variant: .selected, icon: .check)
                MomentsChip("+ 날짜", variant: .dashed)
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
                .font(MomentsTypography.krBody(MomentsTypography.Size.small, weight: .semibold))
                .foregroundColor(MomentsColor.taupe)
            HStack(spacing: 12) {
                radiusSwatch("film 4", radius: MomentsRadius.film)
                radiusSwatch("button 4", radius: MomentsRadius.button)
                radiusSwatch("card 8", radius: MomentsRadius.card)
                radiusSwatch("sheet 16", radius: MomentsRadius.sheet)
            }
        }
    }

    private func radiusSwatch(_ label: String, radius: CGFloat) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(MomentsColor.Purple.p100)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(MomentsColor.coral, lineWidth: 1)
                )
                .frame(height: 56)
            Text(label)
                .font(MomentsTypography.monoFallback(MomentsTypography.Size.caption))
                .foregroundColor(MomentsColor.taupe)
        }
        .frame(maxWidth: .infinity)
    }

    private var shadowRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shadow (#000000 20% blur 6 표준)")
                .font(MomentsTypography.krBody(MomentsTypography.Size.small, weight: .semibold))
                .foregroundColor(MomentsColor.taupe)
            HStack(spacing: 16) {
                shadowSwatch("sm", layers: MomentsShadow.sm)
                shadowSwatch("md", layers: MomentsShadow.md)
                shadowSwatch("lg", layers: MomentsShadow.lg)
            }
        }
    }

    private func shadowSwatch(_ label: String, layers: [MomentsShadowLayer]) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: MomentsRadius.card, style: .continuous)
                .fill(Color.white)
                .frame(width: 80, height: 56)
                .momentsShadow(layers)
            Text(label)
                .font(MomentsTypography.monoFallback(MomentsTypography.Size.caption))
                .foregroundColor(MomentsColor.taupe)
        }
    }

    private var spacingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spacing (4pt base)")
                .font(MomentsTypography.krBody(MomentsTypography.Size.small, weight: .semibold))
                .foregroundColor(MomentsColor.taupe)
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
                .fill(MomentsColor.coral)
                .frame(width: 24, height: value)
            Text(label)
                .font(MomentsTypography.monoFallback(MomentsTypography.Size.caption))
                .foregroundColor(MomentsColor.taupe)
        }
        .frame(width: 36)
    }

    // MARK: - Helpers

    private func sectionShell<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(MomentsTypography.title(MomentsTypography.Size.big, weight: .bold))
                    .foregroundColor(MomentsColor.ink)
                Spacer()
                Rectangle()
                    .fill(MomentsColor.Gray.g200)
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
            MomentsTextField(label: "필름 제목", placeholder: "예: 제주도, 우리의 봄", helper: "비워두면 자동으로 채워져요.", text: $text)
            MomentsTextField(label: "에러 상태", placeholder: "값을 입력하세요", errorText: "30자 이내로 입력해 주세요.", text: $failing)
        }
    }
}

#Preview {
    DesignSystemShowcaseView()
}
