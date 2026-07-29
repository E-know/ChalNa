import SwiftUI
import ComposableArchitecture
import Models
import DesignSystem

public struct LabelPositionSettingsView: View {
    let store: StoreOf<LabelPositionSettingsFeature>

    public init(store: StoreOf<LabelPositionSettingsFeature>) {
        self.store = store
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                verbatimTitle: "\(store.kind.title) 위치",
                leading: .back { store.send(.backTapped) },
                showsDivider: true
            )
            .zIndex(1)

            ScrollView {
                VStack(spacing: 24) {
                    preview
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    grid
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 64)
            }
        }
        .chalNaScreen()
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Mini preview (9:16 중립 캔버스)

    private var preview: some View {
        ZStack(alignment: alignment(for: store.selected)) {
            RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                .fill(ChalNaColor.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: ChalNaRadius.md, style: .continuous)
                        .strokeBorder(ChalNaColor.border, lineWidth: 1)
                )

            sampleLabel
                .padding(12)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: 200)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var sampleLabel: some View {
        if store.kind == .time {
            Text(verbatim: store.kind.sampleText)
                .font(ChalNaTypography.keris(40))
                .foregroundColor(ChalNaColor.textPrimary.opacity(0.6))
        } else {
            Text(verbatim: store.kind.sampleText)
                .font(ChalNaTypography.keris(13))
                .foregroundColor(ChalNaColor.textPrimary)
        }
    }

    /// LabelPosition → SwiftUI(상단 원점) Alignment.
    private func alignment(for p: LabelPosition) -> Alignment {
        let h: HorizontalAlignment = p.horizontalAnchor == 0 ? .leading
        : (p.horizontalAnchor == 1 ? .trailing : .center)
        let v: VerticalAlignment
        switch p {
            case .topLeft, .topCenter, .topRight:          v = .top
            case .centerLeft, .center, .centerRight:       v = .center
            case .bottomLeft, .bottomCenter, .bottomRight: v = .bottom
        }
        return Alignment(horizontal: h, vertical: v)
    }

    // MARK: - 3×3 grid (텍스트 대신 도형으로 위치를 시각화)

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(LabelPosition.allCases, id: \.self) { pos in
                let isSelected = store.selected == pos
                Button { store.send(.positionSelected(pos)) } label: {
                    positionCell(pos, isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: pos.koreanName))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    /// 9칸 미니 도형으로 위치를 표현한다 — 글자보다 훨씬 빨리 읽힌다.
    private func positionCell(_ pos: LabelPosition, isSelected: Bool) -> some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { column in
                        RoundedRectangle(cornerRadius: ChalNaRadius.xxs, style: .continuous)
                            .fill(cellFill(pos, row: row, column: column, isSelected: isSelected))
                            .frame(width: 10, height: 6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                .fill(isSelected ? ChalNaColor.accentFill.opacity(0.20) : ChalNaColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ChalNaRadius.sm, style: .continuous)
                .strokeBorder(isSelected ? ChalNaColor.accent : ChalNaColor.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private func cellFill(_ pos: LabelPosition, row: Int, column: Int, isSelected: Bool) -> Color {
        let target = gridSlot(for: pos)
        guard target.row == row, target.column == column else {
            return ChalNaColor.border
        }
        return isSelected ? ChalNaColor.accent : ChalNaColor.textSecondary
    }

    /// LabelPosition → 3×3 격자 좌표 (row 0 = 위, column 0 = 좌).
    private func gridSlot(for pos: LabelPosition) -> (row: Int, column: Int) {
        switch pos {
        case .topLeft:      return (0, 0)
        case .topCenter:    return (0, 1)
        case .topRight:     return (0, 2)
        case .centerLeft:   return (1, 0)
        case .center:       return (1, 1)
        case .centerRight:  return (1, 2)
        case .bottomLeft:   return (2, 0)
        case .bottomCenter: return (2, 1)
        case .bottomRight:  return (2, 2)
        }
    }
}

#Preview {
    LabelPositionSettingsView(
        store: Store(initialState: LabelPositionSettingsFeature.State(kind: .time)) { LabelPositionSettingsFeature() }
    )
}
