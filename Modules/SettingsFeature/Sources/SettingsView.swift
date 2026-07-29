import SwiftUI
import ComposableArchitecture
import DesignSystem

/// 설정 최상위 메뉴. 현재 '라벨' 항목 1개 — 향후 다른 메뉴 행을 카드에 추가.
public struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                title: "설정",
                leading: .back { store.send(.backTapped) },
                showsDivider: true
            )
            .zIndex(1)

            ScrollView {
                ChalNaCard(padding: 0) {
                    VStack(spacing: 0) {
                        ChalNaListRow.navigate(
                            title: "라벨",
                            subtitle: "영상에 표시되는 시각·날짜 라벨"
                        ) { store.send(.labelMenuTapped) }

                        ChalNaListDivider()

                        ChalNaListRow.navigate(
                            title: "언어",
                            subtitle: "앱 표시 언어를 선택하세요"
                        ) { store.send(.languageMenuTapped) }

                        ChalNaListDivider()

                        ChalNaListRow.navigate(
                            title: "문의·신고",
                            subtitle: "불편한 점이나 제안을 보내주세요"
                        ) { store.send(.supportMenuTapped) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .chalNaScreen()
        .onAppear { store.send(.onAppear) }
    }
}

#Preview {
    SettingsView(store: Store(initialState: SettingsFeature.State()) { SettingsFeature() })
}
