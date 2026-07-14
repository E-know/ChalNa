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
            ChalNaNavigationBar(title: "\(store.kind.title) 위치") {
                ChalNaHeaderBackButton { store.send(.backTapped) }
            } trailing: {
                EmptyView()
            }
            .chalNaHeaderBar(scrollProgress: 1)
            .zIndex(1)

            ScrollView {
                VStack(spacing: 24) {
                    preview
                        .padding(.horizontal, 24)
                        .padding(.top, 16)

                    grid
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 64)
            }
        }
        .chalNaScreen()
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Mini preview (9:16 중립 회색 캔버스)

    private var preview: some View {
        ZStack(alignment: alignment(for: store.selected)) {
            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                .fill(ChalNaColor.Gray.g200)

            sampleLabel
                .padding(12)
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .frame(maxWidth: 220)
    }

    @ViewBuilder
    private var sampleLabel: some View {
        if store.kind == .time {
            Text(store.kind.sampleText)
                .font(ChalNaTypography.keris(40))
                .foregroundColor(.white.opacity(0.5))
        } else {
            Text(store.kind.sampleText)
                .font(ChalNaTypography.keris(13))
                .foregroundColor(.white)
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

    // MARK: - 3×3 grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(LabelPosition.allCases, id: \.self) { pos in
                let isSelected = store.selected == pos
                Button { store.send(.positionSelected(pos)) } label: {
                    Text(pos.koreanName)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g900)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                                .fill(isSelected ? ChalNaColor.Purple.p100.opacity(0.5) : Color.white)
                                .strokeBorder(isSelected ? ChalNaColor.Purple.p600 : ChalNaColor.Gray.g200,
                                              lineWidth: isSelected ? 0 : 10)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    LabelPositionSettingsView(
        store: Store(initialState: LabelPositionSettingsFeature.State(kind: .time)) { LabelPositionSettingsFeature() }
    )
}
