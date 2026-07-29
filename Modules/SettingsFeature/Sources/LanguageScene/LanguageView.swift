import SwiftUI
import ComposableArchitecture
import AppCore
import DesignSystem

/// 앱 표시 언어 선택 화면. 실제 상태는 AppLanguageStore(@Observable env)가 보유.
public struct LanguageView: View {
    @Environment(AppLanguageStore.self) private var languageStore
    let store: StoreOf<LanguageFeature>

    public init(store: StoreOf<LanguageFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            ChalNaNavBar(
                title: "언어",
                leading: .back { store.send(.backTapped) },
                showsDivider: true
            )
            .zIndex(1)

            ScrollView {
                ChalNaCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, lang in
                            if index > 0 { ChalNaListDivider() }
                            // displayName 은 이미 해석된 String → verbatim.
                            ChalNaListRow.check(
                                verbatimTitle: lang.displayName,
                                isChecked: lang == languageStore.language
                            ) {
                                languageStore.set(lang)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .chalNaScreen()
    }
}

#Preview {
    LanguageView(store: Store(initialState: LanguageFeature.State(), reducer: {
        LanguageFeature()
    }))
    .environment(AppLanguageStore())
}
