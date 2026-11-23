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
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, lang in
                    if index > 0 { ChalNaListDivider() }
                    ChalNaListRow.check(
                        verbatimTitle: lang.displayName,
                        isChecked: lang == languageStore.language
                    ) {
                        store.send(.selected(lang))
                    }
                }
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .chalNaScreen()
        .navigationTitle("언어")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    LanguageView(store: Store(initialState: LanguageFeature.State(), reducer: {
        LanguageFeature()
    }))
    .environment(AppLanguageStore())
}
