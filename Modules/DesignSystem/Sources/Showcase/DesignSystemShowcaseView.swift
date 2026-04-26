import SwiftUI

/// 무드보드 5섹션을 SwiftUI로 축약 재현. 앱 실행 시 첫 화면으로 노출.
public struct DesignSystemShowcaseView: View {
    public init() {}

    public var body: some View {
        ZStack {
            MomentsColor.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 48) {
                    coverSection
                    dividerLine
                    colorSection
                    dividerLine
                    typographySection
                    dividerLine
                    componentsSection
                    dividerLine
                    texturesSection
                    footer
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 40)
            }
        }
        .overlay(PaperGrainOverlay(opacity: 0.25))
        .momentsVignette(0.08)
    }

    // MARK: - 01 Cover

    private var coverSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(num: "01", label: "COVER / TITLE")

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    (Text("Moments")
                        .font(MomentsTypography.serifFallback(64, italic: true))
                        .foregroundColor(MomentsColor.ink)
                     + Text(".")
                        .foregroundColor(MomentsColor.coral))

                    Text("— Design System")
                        .font(MomentsTypography.handFallback(28))
                        .foregroundColor(MomentsColor.coral)
                        .rotationEffect(.degrees(-2))

                    Text("여행의 순간들을 자동으로 이어 붙여\n한 편의 필름처럼 기록하는 iOS 앱의 디자인 토큰.")
                        .font(MomentsTypography.krBody(14))
                        .foregroundColor(MomentsColor.ink)
                        .padding(.top, 8)
                }
                Spacer()
                StampBadge("Draft · v0.1")
            }
        }
    }

    // MARK: - 02 Colors

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(num: "02", label: "COLOR · PALETTE")

            FilmStripBackground {
                VStack(spacing: 14) {
                    paletteRow([
                        (MomentsColor.cream, "Cream",       "#FBF6EE", "BACKGROUND"),
                        (MomentsColor.ivory, "Warm Ivory",  "#F2E9D8", "SURFACE"),
                        (MomentsColor.coral, "Sunset Coral", "#E8A598", "CTA · ACCENT"),
                        (MomentsColor.sage,  "Dusty Sage",  "#A8B89E", "SECONDARY")
                    ])
                    paletteRow([
                        (MomentsColor.denim, "Faded Denim", "#7A92A8", "INFO · LINK"),
                        (MomentsColor.ink,   "Ink Brown",   "#3D2E24", "TEXT · PRIMARY"),
                        (MomentsColor.taupe, "Soft Taupe",  "#8B7968", "TEXT · SUB"),
                        (MomentsColor.coral, "Primary",     "—",       "60 · 30 · 10")
                    ])
                }
            }
        }
    }

    private func paletteRow(_ swatches: [(Color, String, String, String)]) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(swatches.enumerated()), id: \.offset) { _, s in
                swatchCell(color: s.0, name: s.1, hex: s.2, usage: s.3)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func swatchCell(color: Color, name: String, hex: String, usage: String) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 64, height: 64)
                .overlay(
                    Circle().strokeBorder(MomentsColor.ink.opacity(0.12), lineWidth: 1)
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.55),
                                      style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        .padding(7)
                )
            Text(name)
                .font(MomentsTypography.serifFallback(13, italic: true))
                .foregroundColor(MomentsColor.cream)
            Text(hex)
                .font(MomentsTypography.monoFallback(9))
                .foregroundColor(MomentsColor.cream.opacity(0.7))
            Text(usage)
                .font(MomentsTypography.monoFallback(8, weight: .medium))
                .tracking(0.8)
                .foregroundColor(Color(hex: 0xC8B894))
        }
    }

    // MARK: - 03 Typography

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(num: "03", label: "TYPE · SYSTEM")

            HStack(alignment: .top, spacing: 16) {
                typeCardEN.frame(maxWidth: .infinity)
                typeCardKR.frame(maxWidth: .infinity)
            }

            scaleRuler
        }
    }

    private var typeCardEN: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DISPLAY · EN · Fraunces")
                .tagLabel()
            (Text("Moments\n").font(MomentsTypography.serifFallback(44, italic: true))
             + Text("of summer").font(MomentsTypography.serifFallback(44, italic: false))
             + Text(".").foregroundColor(MomentsColor.coral))
                .foregroundColor(MomentsColor.ink)
                .lineSpacing(-8)
            Divider().background(MomentsColor.taupe.opacity(0.3))
            Text("Warm afternoon light.")
                .font(MomentsTypography.serifFallback(22, italic: false))
                .foregroundColor(MomentsColor.ink)
            Text("The shutter falls, the film keeps turning. Softly, like a page in an old diary.")
                .font(MomentsTypography.serifFallback(14, italic: false))
                .foregroundColor(MomentsColor.ink)
        }
        .padding(20)
        .background(MomentsColor.ivory)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .momentsShadow(MomentsShadow.md)
    }

    private var typeCardKR: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DISPLAY · KR · Pretendard 700").tagLabel()
            (Text("여행의\n순간들")
                .font(MomentsTypography.displayKR(40, weight: .bold))
             + Text(".").foregroundColor(MomentsColor.coral))
                .foregroundColor(MomentsColor.ink)
                .tracking(-0.5)
                .lineSpacing(2)
            Divider().background(MomentsColor.taupe.opacity(0.3))
            Text("오늘의 라이브 포토를 한 편의 영상으로.")
                .font(MomentsTypography.krSemibold(18))
                .foregroundColor(MomentsColor.ink)
            Text("촬영일 순서대로 자동으로 이어붙여,\n편집 없이 여행의 기분을 그대로 담아드려요.")
                .font(MomentsTypography.krBody(14))
                .foregroundColor(MomentsColor.ink)
            Text("제주, 사월의 오후 · 총 12컷")
                .font(MomentsTypography.krBody(12, weight: .medium))
                .foregroundColor(MomentsColor.taupe)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .momentsShadow(MomentsShadow.md)
    }

    private var scaleRuler: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TYPE · SCALE").tagLabel()
            HStack(alignment: .bottom, spacing: 16) {
                ForEach([CGFloat(48), 32, 24, 18, 16, 14, 10], id: \.self) { size in
                    VStack(spacing: 4) {
                        Text("가")
                            .font(.system(size: size, weight: .bold))
                            .foregroundColor(MomentsColor.ink)
                        Text("\(Int(size))").tagLabel()
                    }
                }
            }
            .padding(12)
            .background(MomentsColor.ivory.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(MomentsColor.taupe.opacity(0.35),
                                   style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            )
        }
    }

    // MARK: - 04 Components

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(num: "04", label: "COMPONENTS")

            // Polaroid row
            VStack(alignment: .leading, spacing: 8) {
                Text("POLAROID · -2° / 0° / +2°").tagLabel()
                HStack(alignment: .bottom, spacing: 14) {
                    PolaroidCard(rotation: .left,   width: 120, caption: "Jeju, 04.05", meta: "LIVE · 01 / 24", topTape: true) {
                        placeholderA
                    }
                    PolaroidCard(rotation: .center, width: 130, caption: "소길리, 오후 4시", meta: "VIDEO · 00:03", topTape: true) {
                        placeholderB
                    }
                    PolaroidCard(rotation: .right,  width: 120, caption: "Last light ◦", meta: "LIVE · 18 / 24") {
                        placeholderC
                    }
                }
                .padding(.top, 16)
                .frame(maxWidth: .infinity)
            }

            // Buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("BUTTONS · 3 STYLES").tagLabel()
                HStack(spacing: 12) {
                    Button { } label: {
                        HStack(spacing: 6) {
                            MomentsIcon(.play, size: 14)
                            Text("Vlog 만들기")
                        }
                    }.buttonStyle(.momentsCoral)
                    Button("불러오기") { }.buttonStyle(.momentsOutline)
                    Button("나중에 하기 →") { }.buttonStyle(.momentsText)
                }
            }

            // Chips
            VStack(alignment: .leading, spacing: 8) {
                Text("CHIPS · TAGS").tagLabel()
                HStack(spacing: 8) {
                    MomentsChip("LIVE",     variant: .live)
                    MomentsChip("VIDEO",    variant: .video,    icon: .film)
                    MomentsChip("SELECTED", variant: .selected, icon: .plus)
                    MomentsChip("+ 날짜",    variant: .dashed)
                }
            }

            // Icons
            VStack(alignment: .leading, spacing: 8) {
                Text("ICONS · 1.5 STROKE · LUCIDE").tagLabel()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(MomentsIconKind.allCases, id: \.self) { kind in
                        VStack(spacing: 4) {
                            MomentsIcon(kind, size: 26)
                                .foregroundColor(MomentsColor.ink)
                            Text(kind.rawValue).tagLabel()
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(MomentsColor.taupe.opacity(0.35),
                                       style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                )
            }
        }
    }

    // MARK: - 05 Textures

    private var texturesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(num: "05", label: "TEXTURE · TOKENS")

            HStack(alignment: .top, spacing: 16) {
                shadowsBlock.frame(maxWidth: .infinity)
                radiiBlock.frame(width: 130)
            }

            spacingBlock
            principlesBlock
        }
    }

    private var shadowsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SHADOWS · 3 LEVELS").tagLabel()
            HStack(spacing: 12) {
                shadowSample("sm", shadow: MomentsShadow.sm, radius: 12)
                shadowSample("md", shadow: MomentsShadow.md, radius: 16)
                shadowSample("lg", shadow: MomentsShadow.lg, radius: 20)
            }
        }
    }

    private func shadowSample(_ label: String, shadow: [MomentsShadowLayer], radius: CGFloat) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white)
                .frame(height: 80)
                .momentsShadow(shadow)
            Text(label.uppercased()).tagLabel()
        }
    }

    private var radiiBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RADIUS").tagLabel()
            radiusRow(4, "POLAROID")
            radiusRow(16, "CARD")
            radiusRow(20, "MODAL")
        }
    }

    private func radiusRow(_ r: CGFloat, _ label: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(colors: [MomentsColor.ivory, Color(hex: 0xEADFC8)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 42, height: 42)
                .overlay(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .strokeBorder(MomentsColor.ink.opacity(0.12), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(r)) px")
                    .font(MomentsTypography.serifFallback(14, italic: true))
                    .foregroundColor(MomentsColor.ink)
                Text(label).tagLabel()
            }
        }
    }

    private var spacingBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SPACING · 4pt BASE").tagLabel()
            HStack(alignment: .bottom, spacing: 8) {
                ForEach([CGFloat(4), 8, 12, 16, 24, 32, 48, 64, 96], id: \.self) { step in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(step == 24 || step == 96 ? MomentsColor.coral : MomentsColor.ink)
                            .frame(width: 4, height: step)
                        Text("\(Int(step))").tagLabel()
                    }
                }
            }
        }
    }

    private var principlesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DESIGN · PRINCIPLES").tagLabel()
            VStack(alignment: .leading, spacing: 6) {
                principle("01.", "편집하지 않은 듯, 편집한 것 — 자동화 뒤의 손맛.")
                principle("02.", "화면은 필름 한 컷, 여백은 빛.")
                principle("03.", "한글 먼저 읽히게, 영문은 노래처럼.")
                principle("04.", "파스텔은 밝지만, 흐리지 않게.")
            }
        }
    }

    private func principle(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(MomentsTypography.serifFallback(14, italic: true))
                .foregroundColor(MomentsColor.coral)
            Text(text)
                .font(MomentsTypography.krBody(14))
                .foregroundColor(MomentsColor.ink)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(num: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(num)
                .font(MomentsTypography.serifFallback(32, italic: true))
                .foregroundColor(MomentsColor.coral)
            Text(label).tagLabel()
            Spacer()
        }
    }

    private var dividerLine: some View {
        ScallopDivider()
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(MomentsColor.coral).frame(width: 8, height: 8)
                Text("MOMENTS · DESIGN SYSTEM").tagLabel()
            }
            Spacer()
            StampBadge("Keep · Analog", angle: 4)
        }
        .padding(.top, 32)
    }

    // MARK: - Image placeholders

    private var placeholderA: some View {
        LinearGradient(
            colors: [Color(hex: 0xF3C9A8), Color(hex: 0xC98B72)],
            startPoint: .top, endPoint: .bottom
        )
    }
    private var placeholderB: some View {
        LinearGradient(
            colors: [Color(hex: 0xA8B89E), Color(hex: 0x3D5240)],
            startPoint: .top, endPoint: .bottom
        )
    }
    private var placeholderC: some View {
        LinearGradient(
            colors: [Color(hex: 0xC9B9A0), Color(hex: 0x8D7A61)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

#Preview {
    DesignSystemShowcaseView()
}
