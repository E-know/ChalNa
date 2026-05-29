import SwiftUI
import ComposableArchitecture
import AppCore
import Models
import DesignSystem

public struct LabelPositionPickerView: View {
    @Environment(AppRouter.self) private var router
    let store: StoreOf<LabelPositionFeature>

    public init(store: StoreOf<LabelPositionFeature>) {
        self.store = store
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    public var body: some View {
        VStack(spacing: 0) {
            header
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

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("\(store.kind.title) 위치")
                .font(ChalNaTypography.title(ChalNaTypography.Size.h2, weight: .semibold))
                .foregroundColor(ChalNaColor.ink)
            HStack {
                Button { router.pop() } label: {
                    ChalNaIcon(.chevronLeft, size: 22)
                        .foregroundColor(ChalNaColor.ink)
                }
                .buttonStyle(.chalNaHeaderAction)
                .accessibilityLabel("뒤로")
                Spacer()
            }
        }
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
        .frame(maxWidth: .infinity)
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
                        .font(ChalNaTypography.krBody(ChalNaTypography.Size.small, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? ChalNaColor.coral : ChalNaColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                                .fill(isSelected ? ChalNaColor.Purple.p100.opacity(0.5) : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                                .strokeBorder(isSelected ? ChalNaColor.coral : ChalNaColor.Gray.g200,
                                              lineWidth: isSelected ? 1.5 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    LabelPositionPickerView(
        store: Store(initialState: LabelPositionFeature.State(kind: .time)) { LabelPositionFeature() }
    )
    .environment(AppRouter())
}
