import SwiftUI
import ComposableArchitecture
import AppCore
import DesignSystem

/// 앱 표시 언어 선택 화면. 실제 상태는 AppLanguageStore(@Observable env)가 보유.
public struct LanguageView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppLanguageStore.self) private var languageStore
    let store: StoreOf<LanguageFeature>

    public init(store: StoreOf<LanguageFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
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
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ChalNaRadius.card, style: .continuous)
                        .strokeBorder(ChalNaColor.Gray.g100, lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .chalNaScreen()
    }

    private func languageRow(_ lang: AppLanguage) -> some View {
        Button {
            languageStore.set(lang)
        } label: {
            HStack(spacing: 12) {
                // displayName 은 이미 해석된 String → verbatim 표시(system 만 String(localized:)).
                Text(lang.displayName)
                    .font(ChalNaTypography.krBody(ChalNaTypography.Size.body))
                    .foregroundColor(ChalNaColor.ink)
                Spacer()
                if lang == languageStore.language {
                    ChalNaIcon(.check, size: 20)
                        .foregroundColor(ChalNaColor.coral)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        ZStack {
            Text("언어")
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
}
