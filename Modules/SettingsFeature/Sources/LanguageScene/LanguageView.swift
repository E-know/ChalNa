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
            ChalNaNavigationBar(titleKey: "언어") {
                ChalNaHeaderBackButton { store.send(.backTapped) }
            } trailing: {
                EmptyView()
            }
            .chalNaHeaderBar(scrollProgress: 1)
            .zIndex(1)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { index, lang in
                        if index > 0 {
                            Divider().overlay(ChalNaColor.Gray.g100)
                        }
                        languageRow(lang)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                        .fill(Color.white)
                        .stroke(ChalNaColor.Gray.g100, lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    private func languageRow(_ lang: AppLanguage) -> some View {
        Button {
            languageStore.set(lang)
        } label: {
            HStack(spacing: 12) {
                // displayName 은 이미 해석된 String → verbatim 표시(system 만 String(localized:)).
                Text(lang.displayName)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                    .foregroundColor(ChalNaColor.Gray.g900)
                Spacer()
                if lang == languageStore.language {
                    Image(systemName: "checkmark")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(ChalNaColor.Purple.p600)
                        .frame(height: 14)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LanguageView(store: Store(initialState: LanguageFeature.State(), reducer: {
        LanguageFeature()
    }))
    .environment(AppLanguageStore())
}
