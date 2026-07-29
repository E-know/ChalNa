import SwiftUI
import ComposableArchitecture
import Models
import DesignSystem

public struct LabelSettingsView: View {
    let store: StoreOf<LabelSettingsFeature>

    public init(store: StoreOf<LabelSettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                title: "라벨",
                leading: .back { store.send(.backTapped) },
                showsDivider: true
            )
            .zIndex(1)

            ScrollView {
                ChalNaCard(padding: 0) {
                    VStack(spacing: 0) {
                        labelRows(
                            kind: .time,
                            isOn: store.timeEnabled,
                            position: store.timePosition,
                            opacity: store.timeOpacity,
                            onToggle: { store.send(.timeToggled($0)) },
                            onPositionTap: { store.send(.timePositionRowTapped) },
                            onOpacityChange: { store.send(.timeOpacityChanged($0)) }
                        )

                        ChalNaListDivider()

                        labelRows(
                            kind: .date,
                            isOn: store.dateEnabled,
                            position: store.datePosition,
                            opacity: store.dateOpacity,
                            onToggle: { store.send(.dateToggled($0)) },
                            onPositionTap: { store.send(.datePositionRowTapped) },
                            onOpacityChange: { store.send(.dateOpacityChanged($0)) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .chalNaScreen()
    }

    // MARK: - Rows

    @ViewBuilder
    private func labelRows(
        kind: LabelKind,
        isOn: Bool,
        position: LabelPosition,
        opacity: Double,
        onToggle: @escaping (Bool) -> Void,
        onPositionTap: @escaping () -> Void,
        onOpacityChange: @escaping (Double) -> Void
    ) -> some View {
        // LabelKind.title/.subtitle 은 String(localized:) 로 이미 해석된 String 이다
        // (Models/Sources/LabelSettings.swift:86,93). verbatim 변형을 써야 이중 조회를 피한다.
        ChalNaListRow.toggleVerbatim(
            title: kind.title,
            subtitle: kind.subtitle,
            isOn: isOn,
            onChange: onToggle
        )

        ChalNaListDivider()

        ChalNaListRow.navigate(
            title: "위치",
            value: position.koreanName,
            enabled: isOn,
            action: onPositionTap
        )

        ChalNaListDivider()

        ChalNaListRow.slider(
            title: "투명도",
            value: opacity,
            enabled: isOn,
            trailingText: "\(Int((opacity * 100).rounded()))%",
            onChange: onOpacityChange
        )
    }
}

#Preview {
    LabelSettingsView(store: Store(initialState: LabelSettingsFeature.State()) { LabelSettingsFeature() })
}
